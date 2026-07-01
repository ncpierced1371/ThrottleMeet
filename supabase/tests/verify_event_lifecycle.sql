-- Verify authenticated owner-only event edit and cancellation behavior.
--
-- Run manually after all migrations with a local/staging database-owner
-- session that may insert auth.users fixtures and SET ROLE. The transaction is
-- rolled back, so no fixture data persists.

begin;

delete from public.events
where id in (
  'lifecycle-edit-event',
  'lifecycle-cancel-event',
  'lifecycle-ownerless-event'
);

delete from auth.users
where id in (
  '30000000-0000-4000-8000-000000000001'::uuid,
  '30000000-0000-4000-8000-000000000002'::uuid
);

insert into auth.users (id)
values
  ('30000000-0000-4000-8000-000000000001'::uuid),
  ('30000000-0000-4000-8000-000000000002'::uuid);

-- Retain an ownerless legacy fixture. It remains readable, but no
-- authenticated user may acquire mutation rights over it.
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
  'lifecycle-ownerless-event',
  'Ownerless Legacy Event',
  'Retained legacy fixture',
  'Legacy Garage',
  'Legacy Host',
  pg_catalog.now() + interval '4 days',
  pg_catalog.now() + interval '4 days 2 hours',
  null
);

-- Anonymous callers must not execute either owner mutation RPC.
select pg_catalog.set_config('request.jwt.claim.sub', '', true);
set local role anon;

do $$
declare
  update_rejected boolean := false;
  cancel_rejected boolean := false;
begin
  begin
    perform public.update_event_v2(
      event_id => 'lifecycle-ownerless-event',
      title => 'Must Not Update',
      description => 'Anonymous update attempt',
      location_name => 'Nowhere',
      host_name => 'Anonymous Caller',
      start_time => pg_catalog.now() + interval '4 days',
      end_time => pg_catalog.now() + interval '4 days 1 hour'
    );
  exception
    when insufficient_privilege then update_rejected := true;
  end;

  begin
    perform public.cancel_event_v2('lifecycle-ownerless-event');
  exception
    when insufficient_privilege then cancel_rejected := true;
  end;

  if not update_rejected or not cancel_rejected then
    raise exception 'anon unexpectedly executed an owner lifecycle RPC';
  end if;
end;
$$;

reset role;

-- User A creates two independently owned fixtures through the authenticated
-- creation path: one for edit checks and one for cancellation checks.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '30000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  confirmation jsonb;
  projected record;
  direct_update_rejected boolean := false;
  ownerless_edit_rejected boolean := false;
  ownerless_cancel_rejected boolean := false;
begin
  perform public.create_event_with_creator_rsvp_v2(
    event_id => 'lifecycle-edit-event',
    title => 'Lifecycle Edit Fixture',
    description => 'Before owner edit',
    location_name => 'Original Garage',
    host_name => 'Original Host',
    start_time => pg_catalog.now() + interval '2 days',
    end_time => pg_catalog.now() + interval '2 days 2 hours'
  );

  perform public.create_event_with_creator_rsvp_v2(
    event_id => 'lifecycle-cancel-event',
    title => 'Lifecycle Cancel Fixture',
    description => 'Before owner cancellation',
    location_name => 'Cancellation Garage',
    host_name => 'Owner A',
    start_time => pg_catalog.now() + interval '3 days',
    end_time => pg_catalog.now() + interval '3 days 2 hours'
  );

  confirmation := public.update_event_v2(
    event_id => 'lifecycle-edit-event',
    title => 'Lifecycle Edit Fixture Updated',
    description => 'After owner edit',
    location_name => 'Updated Garage',
    host_name => 'Updated Host',
    start_time => pg_catalog.now() + interval '2 days 1 hour',
    end_time => pg_catalog.now() + interval '2 days 3 hours'
  );

  if confirmation ->> 'id' is distinct from 'lifecycle-edit-event'
    or confirmation ->> 'title' is distinct from 'Lifecycle Edit Fixture Updated'
    or confirmation ->> 'description' is distinct from 'After owner edit'
    or confirmation ->> 'location_name' is distinct from 'Updated Garage'
    or confirmation ->> 'host_name' is distinct from 'Updated Host'
    or confirmation ->> 'updated_at' is null then
    raise exception 'owner edit confirmation is incorrect';
  end if;

  -- Exercise the active-event update path without parameter/column ambiguity.
  if public.set_event_rsvp_v2(
    event_id => 'lifecycle-edit-event',
    status => 'interested'
  ) is distinct from 'interested' then
    raise exception 'active event RSVP update failed';
  end if;

  select title, description, location_name, host_name, attendee_count,
    rsvp_status, status, cancelled_at, is_owner
  into strict projected
  from public.get_events_for_current_user()
  where id = 'lifecycle-edit-event';

  if projected.title is distinct from 'Lifecycle Edit Fixture Updated'
    or projected.description is distinct from 'After owner edit'
    or projected.location_name is distinct from 'Updated Garage'
    or projected.host_name is distinct from 'Updated Host'
    or projected.attendee_count is distinct from 0
    or projected.rsvp_status is distinct from 'interested'
    or projected.status is distinct from 'active'
    or projected.cancelled_at is not null
    or projected.is_owner is distinct from true then
    raise exception 'owner lifecycle projection after edit is incorrect';
  end if;

  select status, cancelled_at, is_owner
  into strict projected
  from public.get_events_for_current_user()
  where id = 'lifecycle-ownerless-event';

  if projected.status is distinct from 'active'
    or projected.cancelled_at is not null
    or projected.is_owner is distinct from false then
    raise exception 'ownerless event lifecycle projection is incorrect';
  end if;

  begin
    perform public.update_event_v2(
      event_id => 'lifecycle-ownerless-event',
      title => 'Must Not Update',
      description => 'Ownerless edit attempt',
      location_name => 'Nowhere',
      host_name => 'User A',
      start_time => pg_catalog.now() + interval '4 days',
      end_time => pg_catalog.now() + interval '4 days 1 hour'
    );
  exception
    when insufficient_privilege then ownerless_edit_rejected := true;
  end;

  begin
    perform public.cancel_event_v2('lifecycle-ownerless-event');
  exception
    when insufficient_privilege then ownerless_cancel_rejected := true;
  end;

  begin
    update public.events
    set title = 'Direct Update Must Fail'
    where id = 'lifecycle-edit-event';
  exception
    when insufficient_privilege then direct_update_rejected := true;
  end;

  if not ownerless_edit_rejected or not ownerless_cancel_rejected then
    raise exception 'ownerless event unexpectedly allowed a lifecycle mutation';
  end if;

  if not direct_update_rejected then
    raise exception 'authenticated direct event update was unexpectedly allowed';
  end if;
end;
$$;

reset role;

-- User B can read shared lifecycle state but is not the owner and cannot edit
-- or cancel either event owned by user A.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '30000000-0000-4000-8000-000000000002',
  true
);
set local role authenticated;

do $$
declare
  projected record;
  edit_rejected boolean := false;
  cancel_rejected boolean := false;
begin
  select status, cancelled_at, is_owner
  into strict projected
  from public.get_events_for_current_user()
  where id = 'lifecycle-cancel-event';

  if projected.status is distinct from 'active'
    or projected.cancelled_at is not null
    or projected.is_owner is distinct from false then
    raise exception 'non-owner lifecycle projection is incorrect';
  end if;

  -- User B has no RSVP row yet, so this exercises set_event_rsvp_v2's explicit
  -- insert path after its qualified UPDATE finds no match.
  if public.set_event_rsvp_v2(
    event_id => 'lifecycle-edit-event',
    status => 'interested'
  ) is distinct from 'interested' then
    raise exception 'active event RSVP insert path failed';
  end if;

  select attendee_count, rsvp_status, is_owner
  into strict projected
  from public.get_events_for_current_user()
  where id = 'lifecycle-edit-event';

  if projected.attendee_count is distinct from 0
    or projected.rsvp_status is distinct from 'interested'
    or projected.is_owner is distinct from false then
    raise exception 'inserted non-owner RSVP projection is incorrect';
  end if;

  begin
    perform public.update_event_v2(
      event_id => 'lifecycle-edit-event',
      title => 'Must Not Update',
      description => 'Non-owner edit attempt',
      location_name => 'Nowhere',
      host_name => 'User B',
      start_time => pg_catalog.now() + interval '2 days',
      end_time => pg_catalog.now() + interval '2 days 1 hour'
    );
  exception
    when insufficient_privilege then edit_rejected := true;
  end;

  begin
    perform public.cancel_event_v2('lifecycle-cancel-event');
  exception
    when insufficient_privilege then cancel_rejected := true;
  end;

  if not edit_rejected or not cancel_rejected then
    raise exception 'non-owner unexpectedly changed an owned event';
  end if;
end;
$$;

reset role;

-- User A cancels the event. A repeated call must preserve the first
-- cancellation timestamp, and all later edit/RSVP mutations must be rejected.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '30000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  first_confirmation jsonb;
  second_confirmation jsonb;
  projected record;
  cancelled_edit_rejected boolean := false;
  cancelled_rsvp_rejected boolean := false;
begin
  first_confirmation := public.cancel_event_v2('lifecycle-cancel-event');
  second_confirmation := public.cancel_event_v2('lifecycle-cancel-event');

  if first_confirmation ->> 'id' is distinct from 'lifecycle-cancel-event'
    or first_confirmation ->> 'status' is distinct from 'cancelled'
    or first_confirmation ->> 'cancelled_at' is null
    or second_confirmation ->> 'status' is distinct from 'cancelled'
    or (second_confirmation ->> 'cancelled_at')
      is distinct from (first_confirmation ->> 'cancelled_at') then
    raise exception 'owner cancellation was not idempotent';
  end if;

  select status, cancelled_at, is_owner
  into strict projected
  from public.get_events_for_current_user()
  where id = 'lifecycle-cancel-event';

  if projected.status is distinct from 'cancelled'
    or projected.cancelled_at is null
    or projected.is_owner is distinct from true then
    raise exception 'cancelled event was not retained or projected correctly';
  end if;

  begin
    perform public.update_event_v2(
      event_id => 'lifecycle-cancel-event',
      title => 'Must Not Update',
      description => 'Cancelled edit attempt',
      location_name => 'Nowhere',
      host_name => 'Owner A',
      start_time => pg_catalog.now() + interval '3 days',
      end_time => pg_catalog.now() + interval '3 days 1 hour'
    );
  exception
    when invalid_parameter_value then cancelled_edit_rejected := true;
  end;

  begin
    perform public.set_event_rsvp_v2(
      event_id => 'lifecycle-cancel-event',
      status => 'interested'
    );
  exception
    when invalid_parameter_value then cancelled_rsvp_rejected := true;
  end;

  if not cancelled_edit_rejected or not cancelled_rsvp_rejected then
    raise exception 'cancelled event unexpectedly accepted a mutation';
  end if;
end;
$$;

reset role;

-- Confirm at the owner level that soft cancellation retained the physical row.
do $$
declare
  retained_count integer;
begin
  select count(*) into retained_count
  from public.events
  where id = 'lifecycle-cancel-event'
    and status = 'cancelled'
    and cancelled_at is not null;

  if retained_count is distinct from 1 then
    raise exception 'cancelled event was not physically retained';
  end if;
end;
$$;

rollback;
