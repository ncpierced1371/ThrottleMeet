-- Verify the post-v2 security cutoff and authenticated access matrix.
--
-- Run manually after all migrations with a local/staging database-owner
-- session that may insert auth.users fixtures and SET ROLE. The transaction is
-- rolled back, so no fixture data persists.

begin;

delete from public.events
where id in (
  'security-cutoff-v2-event',
  'security-cutoff-direct-event',
  'security-cutoff-legacy-event'
);

delete from auth.users
where id = '20000000-0000-4000-8000-000000000001'::uuid;

insert into auth.users (id)
values ('20000000-0000-4000-8000-000000000001'::uuid);

-- Anonymous callers must have neither direct event reads nor legacy RPC
-- execution. Each statement must fail at the privilege boundary.
select pg_catalog.set_config('request.jwt.claim.sub', '', true);
set local role anon;

do $$
declare
  direct_select_rejected boolean := false;
  legacy_read_rejected boolean := false;
  legacy_rsvp_rejected boolean := false;
  legacy_create_rejected boolean := false;
begin
  begin
    perform 1 from public.events limit 1;
  exception
    when insufficient_privilege then direct_select_rejected := true;
  end;

  begin
    perform public.get_events_for_participant('legacy-participant');
  exception
    when insufficient_privilege then legacy_read_rejected := true;
  end;

  begin
    perform public.set_event_rsvp(
      event_id => 'security-cutoff-v2-event',
      participant_id => 'legacy-participant',
      status => 'going'
    );
  exception
    when insufficient_privilege then legacy_rsvp_rejected := true;
  end;

  begin
    perform public.create_event_with_creator_rsvp(
      event_id => 'security-cutoff-legacy-event',
      title => 'Must Not Be Created',
      description => 'Legacy security cutoff verification',
      location_name => 'Nowhere',
      host_name => 'Anonymous Caller',
      start_time => pg_catalog.now() + interval '1 day',
      end_time => pg_catalog.now() + interval '1 day 1 hour',
      participant_id => 'legacy-participant'
    );
  exception
    when insufficient_privilege then legacy_create_rejected := true;
  end;

  if not direct_select_rejected
    or not legacy_read_rejected
    or not legacy_rsvp_rejected
    or not legacy_create_rejected then
    raise exception 'anonymous security cutoff is incomplete';
  end if;
end;
$$;

reset role;

-- The authenticated role must retain profile self-access and all v2 RPCs.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  created jsonb;
  projected record;
  saved_display_name text;
  direct_event_insert_rejected boolean := false;
  direct_rsvp_insert_rejected boolean := false;
begin
  insert into public.profiles (id, display_name)
  values (auth.uid(), 'Security Cutoff User');

  update public.profiles
  set display_name = 'Security Cutoff User Updated'
  where id = auth.uid();

  select display_name into strict saved_display_name
  from public.profiles
  where id = auth.uid();

  if saved_display_name is distinct from 'Security Cutoff User Updated' then
    raise exception 'authenticated profile self-access failed';
  end if;

  created := public.create_event_with_creator_rsvp_v2(
    event_id => 'security-cutoff-v2-event',
    title => 'Security Cutoff Verification',
    description => 'Authenticated v2 fixture',
    location_name => 'Local Test Garage',
    host_name => 'Authenticated Host',
    start_time => pg_catalog.now() + interval '2 days',
    end_time => pg_catalog.now() + interval '2 days 2 hours'
  );

  if created ->> 'id' is distinct from 'security-cutoff-v2-event'
    or created ->> 'rsvp_status' is distinct from 'going'
    or (created ->> 'attendee_count')::integer is distinct from 1 then
    raise exception 'authenticated v2 create RPC failed';
  end if;

  if public.set_event_rsvp_v2(
    event_id => 'security-cutoff-v2-event',
    status => 'interested'
  ) is distinct from 'interested' then
    raise exception 'authenticated v2 RSVP RPC failed';
  end if;

  select attendee_count, rsvp_status into strict projected
  from public.get_events_for_current_user()
  where id = 'security-cutoff-v2-event';

  if projected.attendee_count is distinct from 0
    or projected.rsvp_status is distinct from 'interested' then
    raise exception 'authenticated v2 event read RPC failed';
  end if;

  begin
    insert into public.events (
      id,
      title,
      description,
      location_name,
      host_name,
      start_time,
      end_time,
      creator_id
    ) values (
      'security-cutoff-direct-event',
      'Must Not Be Inserted Directly',
      'Direct event insert verification',
      'Nowhere',
      'Authenticated Caller',
      pg_catalog.now() + interval '3 days',
      pg_catalog.now() + interval '3 days 1 hour',
      auth.uid()
    );
  exception
    when insufficient_privilege then direct_event_insert_rejected := true;
  end;

  begin
    insert into public.event_rsvps (
      event_id,
      participant_id,
      status
    ) values (
      'security-cutoff-v2-event',
      'security-cutoff-direct-write',
      'going'
    );
  exception
    when insufficient_privilege then direct_rsvp_insert_rejected := true;
  end;

  if not direct_event_insert_rejected then
    raise exception 'authenticated direct event insert was unexpectedly allowed';
  end if;

  if not direct_rsvp_insert_rejected then
    raise exception 'authenticated direct RSVP insert was unexpectedly allowed';
  end if;
end;
$$;

reset role;

rollback;
