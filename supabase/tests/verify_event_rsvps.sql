-- Verify normalized RSVP upserts, participant projections, and aggregation.
-- This script is intentionally transactional so the fixture is rolled back.

begin;

delete from public.events
where id = 'rsvp-integration-verification';

insert into public.events (
  id,
  title,
  description,
  location_name,
  host_name,
  start_time,
  end_time
) values (
  'rsvp-integration-verification',
  'RSVP Integration Verification',
  'Temporary local verification fixture',
  'Local Test Garage',
  'Integration Test',
  now() + interval '1 day',
  now() + interval '1 day 2 hours'
);

-- Participant A RSVPs Going.
do $$
begin
  if public.set_event_rsvp(
    event_id => 'rsvp-integration-verification',
    participant_id => 'participant-a',
    status => 'going'
  ) is distinct from 'going' then
    raise exception 'participant-a RSVP was not saved as going';
  end if;
end;
$$;

-- Participant B RSVPs Going.
do $$
begin
  if public.set_event_rsvp(
    event_id => 'rsvp-integration-verification',
    participant_id => 'participant-b',
    status => 'going'
  ) is distinct from 'going' then
    raise exception 'participant-b RSVP was not saved as going';
  end if;
end;
$$;

-- Preserve row identities so later checks prove updates do not insert new rows.
create temporary table original_rsvp_rows on commit drop as
select participant_id, id
from public.event_rsvps
where event_id = 'rsvp-integration-verification';

-- Both participants are Going, so attendee_count must be 2. Each participant
-- must see their own status, while an unrelated participant sees no status.
do $$
declare
  participant_a record;
  participant_b record;
  observer record;
begin
  select attendee_count, rsvp_status into strict participant_a
  from public.get_events_for_participant('participant-a')
  where id = 'rsvp-integration-verification';

  select attendee_count, rsvp_status into strict participant_b
  from public.get_events_for_participant('participant-b')
  where id = 'rsvp-integration-verification';

  select attendee_count, rsvp_status into strict observer
  from public.get_events_for_participant('participant-c')
  where id = 'rsvp-integration-verification';

  if participant_a.attendee_count is distinct from 2
    or participant_b.attendee_count is distinct from 2
    or observer.attendee_count is distinct from 2 then
    raise exception 'expected attendee_count 2 after two Going RSVPs';
  end if;

  if participant_a.rsvp_status is distinct from 'going'
    or participant_b.rsvp_status is distinct from 'going'
    or observer.rsvp_status is not null then
    raise exception 'participant-specific Going projection is incorrect';
  end if;
end;
$$;

-- Participant A changes to Interested.
do $$
begin
  if public.set_event_rsvp(
    event_id => 'rsvp-integration-verification',
    participant_id => 'participant-a',
    status => 'interested'
  ) is distinct from 'interested' then
    raise exception 'participant-a RSVP was not updated to interested';
  end if;
end;
$$;

-- Only participant B remains Going, so attendee_count must be 1.
do $$
declare
  participant_a record;
  participant_b record;
begin
  select attendee_count, rsvp_status into strict participant_a
  from public.get_events_for_participant('participant-a')
  where id = 'rsvp-integration-verification';

  select attendee_count, rsvp_status into strict participant_b
  from public.get_events_for_participant('participant-b')
  where id = 'rsvp-integration-verification';

  if participant_a.attendee_count is distinct from 1
    or participant_b.attendee_count is distinct from 1 then
    raise exception 'expected attendee_count 1 after participant-a changed RSVP';
  end if;

  if participant_a.rsvp_status is distinct from 'interested'
    or participant_b.rsvp_status is distinct from 'going' then
    raise exception 'participant-specific status projection is incorrect';
  end if;
end;
$$;

-- Participant B changes to Not going. The stored enum value is "notGoing".
do $$
begin
  if public.set_event_rsvp(
    event_id => 'rsvp-integration-verification',
    participant_id => 'participant-b',
    status => 'notGoing'
  ) is distinct from 'notGoing' then
    raise exception 'participant-b RSVP was not updated to notGoing';
  end if;
end;
$$;

-- Nobody remains Going, so attendee_count must be 0.
do $$
declare
  participant_a record;
  participant_b record;
  observer record;
begin
  select attendee_count, rsvp_status into strict participant_a
  from public.get_events_for_participant('participant-a')
  where id = 'rsvp-integration-verification';

  select attendee_count, rsvp_status into strict participant_b
  from public.get_events_for_participant('participant-b')
  where id = 'rsvp-integration-verification';

  select attendee_count, rsvp_status into strict observer
  from public.get_events_for_participant('participant-c')
  where id = 'rsvp-integration-verification';

  if participant_a.attendee_count is distinct from 0
    or participant_b.attendee_count is distinct from 0
    or observer.attendee_count is distinct from 0 then
    raise exception 'expected attendee_count 0 after both Going RSVPs changed';
  end if;

  if participant_a.rsvp_status is distinct from 'interested'
    or participant_b.rsvp_status is distinct from 'notGoing'
    or observer.rsvp_status is not null then
    raise exception 'final participant-specific status projection is incorrect';
  end if;
end;
$$;

-- The two updates must retain exactly one row per event/participant pair and
-- preserve each original row ID, proving ON CONFLICT performed an update.
do $$
declare
  total_rows integer;
  unique_participants integer;
  preserved_row_ids integer;
begin
  select
    count(*),
    count(distinct participant_id)
  into total_rows, unique_participants
  from public.event_rsvps
  where event_id = 'rsvp-integration-verification';

  select count(*)
  into preserved_row_ids
  from public.event_rsvps current_rsvp
  join original_rsvp_rows original
    on original.participant_id = current_rsvp.participant_id
    and original.id = current_rsvp.id
  where current_rsvp.event_id = 'rsvp-integration-verification';

  if total_rows is distinct from 2
    or unique_participants is distinct from 2
    or preserved_row_ids is distinct from 2 then
    raise exception 'unique RSVP upsert behavior is incorrect';
  end if;
end;
$$;

-- Final normalized status totals must be Going=0, Interested=1, NotGoing=1.
do $$
declare
  going_count integer;
  interested_count integer;
  not_going_count integer;
begin
  select
    count(*) filter (where status = 'going'),
    count(*) filter (where status = 'interested'),
    count(*) filter (where status = 'notGoing')
  into going_count, interested_count, not_going_count
  from public.event_rsvps
  where event_id = 'rsvp-integration-verification';

  if going_count is distinct from 0
    or interested_count is distinct from 1
    or not_going_count is distinct from 1 then
    raise exception 'unexpected final RSVP totals';
  end if;
end;
$$;

rollback;
