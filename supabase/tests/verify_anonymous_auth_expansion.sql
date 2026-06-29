-- Verify legacy participant compatibility and the authenticated v2 RSVP path.
--
-- Run manually against a local Supabase database after applying migrations.
-- The session must be allowed to insert fixture rows into auth.users and SET
-- ROLE to anon/authenticated. Nothing persists because the script rolls back.

begin;

delete from public.events
where id in (
  'auth-expansion-legacy-verification',
  'auth-expansion-v2-verification',
  'auth-expansion-anon-must-fail'
);

delete from auth.users
where id in (
  '10000000-0000-4000-8000-000000000001'::uuid,
  '10000000-0000-4000-8000-000000000002'::uuid
);

insert into auth.users (id)
values
  ('10000000-0000-4000-8000-000000000001'::uuid),
  ('10000000-0000-4000-8000-000000000002'::uuid);

-- Legacy anonymous create, RSVP, and participant-aware projection still work.
set local role anon;

do $$
declare
  legacy_event record;
begin
  perform public.create_event_with_creator_rsvp(
    event_id => 'auth-expansion-legacy-verification',
    title => 'Legacy RSVP Verification',
    description => 'Temporary legacy fixture',
    location_name => 'Local Test Garage',
    host_name => 'Legacy Host',
    start_time => pg_catalog.now() + interval '1 day',
    end_time => pg_catalog.now() + interval '1 day 2 hours',
    participant_id => 'legacy-participant-a'
  );

  if public.set_event_rsvp(
    event_id => 'auth-expansion-legacy-verification',
    participant_id => 'legacy-participant-b',
    status => 'going'
  ) is distinct from 'going' then
    raise exception 'legacy RSVP path did not return going';
  end if;

  select attendee_count, rsvp_status into strict legacy_event
  from public.get_events_for_participant('legacy-participant-a')
  where id = 'auth-expansion-legacy-verification';

  if legacy_event.attendee_count is distinct from 2
    or legacy_event.rsvp_status is distinct from 'going' then
    raise exception 'legacy participant projection or aggregation failed';
  end if;
end;
$$;

reset role;

-- User A creates an event. The RPC must derive creator_id from auth.uid() and
-- atomically create that same user's Going RSVP.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  created jsonb;
  projected record;
  saved_creator uuid;
begin
  created := public.create_event_with_creator_rsvp_v2(
    event_id => 'auth-expansion-v2-verification',
    title => 'Authenticated RSVP Verification',
    description => 'Temporary v2 fixture',
    location_name => 'Local Test Garage',
    host_name => 'Authenticated Host',
    start_time => pg_catalog.now() + interval '2 days',
    end_time => pg_catalog.now() + interval '2 days 2 hours'
  );

  if created ->> 'rsvp_status' is distinct from 'going'
    or (created ->> 'attendee_count')::integer is distinct from 1 then
    raise exception 'v2 create did not return the creator Going RSVP';
  end if;

  select creator_id into strict saved_creator
  from public.events
  where id = 'auth-expansion-v2-verification';

  if saved_creator is distinct from auth.uid() then
    raise exception 'v2 create did not save auth.uid() as creator_id';
  end if;

  select attendee_count, rsvp_status into strict projected
  from public.get_events_for_current_user()
  where id = 'auth-expansion-v2-verification';

  if projected.attendee_count is distinct from 1
    or projected.rsvp_status is distinct from 'going' then
    raise exception 'user A projection after v2 create is incorrect';
  end if;
end;
$$;

reset role;

-- User B can RSVP to the shared event but receives only user B's projection.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000002',
  true
);
set local role authenticated;

do $$
declare
  projected record;
  visible_rsvp_rows integer;
begin
  if public.set_event_rsvp_v2(
    event_id => 'auth-expansion-v2-verification',
    status => 'going'
  ) is distinct from 'going' then
    raise exception 'user B v2 RSVP did not return going';
  end if;

  select attendee_count, rsvp_status into strict projected
  from public.get_events_for_current_user()
  where id = 'auth-expansion-v2-verification';

  if projected.attendee_count is distinct from 2
    or projected.rsvp_status is distinct from 'going' then
    raise exception 'two-user attendee aggregation or user B projection failed';
  end if;

  select count(*) into visible_rsvp_rows
  from public.event_rsvps
  where event_id = 'auth-expansion-v2-verification';

  if visible_rsvp_rows is distinct from 1 then
    raise exception 'RLS exposed another user RSVP row to user B';
  end if;
end;
$$;

reset role;

-- Changing user A does not change user B's RSVP projection. Only Going rows
-- contribute to attendee_count, so the aggregate falls from two to one.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  projected record;
begin
  if public.set_event_rsvp_v2(
    event_id => 'auth-expansion-v2-verification',
    status => 'interested'
  ) is distinct from 'interested' then
    raise exception 'user A v2 RSVP did not update to interested';
  end if;

  select attendee_count, rsvp_status into strict projected
  from public.get_events_for_current_user()
  where id = 'auth-expansion-v2-verification';

  if projected.attendee_count is distinct from 1
    or projected.rsvp_status is distinct from 'interested' then
    raise exception 'user A isolated projection after update failed';
  end if;
end;
$$;

reset role;

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000002',
  true
);
set local role authenticated;

do $$
declare
  projected record;
begin
  select attendee_count, rsvp_status into strict projected
  from public.get_events_for_current_user()
  where id = 'auth-expansion-v2-verification';

  if projected.attendee_count is distinct from 1
    or projected.rsvp_status is distinct from 'going' then
    raise exception 'user A update leaked into user B RSVP projection';
  end if;
end;
$$;

reset role;

-- The anon role must have no EXECUTE privilege on any v2 RPC. Each call is
-- expected to fail at the permission boundary before function code runs.
select pg_catalog.set_config('request.jwt.claim.sub', '', true);
set local role anon;

do $$
declare
  get_rejected boolean := false;
  set_rejected boolean := false;
  create_rejected boolean := false;
begin
  begin
    perform public.get_events_for_current_user();
  exception
    when insufficient_privilege then get_rejected := true;
  end;

  begin
    perform public.set_event_rsvp_v2(
      event_id => 'auth-expansion-v2-verification',
      status => 'notGoing'
    );
  exception
    when insufficient_privilege then set_rejected := true;
  end;

  begin
    perform public.create_event_with_creator_rsvp_v2(
      event_id => 'auth-expansion-anon-must-fail',
      title => 'Must Not Be Created',
      description => 'Permission verification',
      location_name => 'Nowhere',
      host_name => 'Anonymous Caller',
      start_time => pg_catalog.now() + interval '3 days',
      end_time => pg_catalog.now() + interval '3 days 1 hour'
    );
  exception
    when insufficient_privilege then create_rejected := true;
  end;

  if not get_rejected or not set_rejected or not create_rejected then
    raise exception 'anon unexpectedly executed one or more v2 RPCs';
  end if;
end;
$$;

reset role;

rollback;
