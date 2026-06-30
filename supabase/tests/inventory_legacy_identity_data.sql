-- Read-only inventory of legacy participant identity data.
--
-- This script intentionally performs SELECT statements only. Run it before
-- deciding whether retained legacy rows should be archived or deleted later.

-- 1. Ownerless events created before authenticated creator ownership.
select
  events.id,
  events.title,
  events.start_time,
  events.created_at
from public.events as events
where events.creator_id is null
order by events.created_at, events.id;

-- 2. RSVP rows without an authenticated user identity.
select
  rsvps.id,
  rsvps.event_id,
  rsvps.participant_id,
  rsvps.status,
  rsvps.created_at,
  rsvps.updated_at
from public.event_rsvps as rsvps
where rsvps.user_id is null
order by rsvps.event_id, rsvps.created_at, rsvps.id;

-- 3. Rows containing both legacy and authenticated identity values.
select
  rsvps.id,
  rsvps.event_id,
  rsvps.participant_id,
  rsvps.user_id,
  rsvps.status,
  rsvps.created_at,
  rsvps.updated_at
from public.event_rsvps as rsvps
where rsvps.participant_id is not null
  and rsvps.user_id is not null
order by rsvps.event_id, rsvps.created_at, rsvps.id;

-- 4. Per-event Going RSVPs backed only by legacy participant identity.
select
  events.id as event_id,
  events.title,
  count(rsvps.id)::integer as legacy_going_count
from public.events as events
join public.event_rsvps as rsvps
  on rsvps.event_id = events.id
  and rsvps.user_id is null
  and rsvps.status = 'going'
group by events.id, events.title
order by events.id;

-- 5. Per-event authenticated Going RSVPs used by the v2 projection.
select
  events.id as event_id,
  events.title,
  count(rsvps.id)::integer as authenticated_going_count
from public.events as events
left join public.event_rsvps as rsvps
  on rsvps.event_id = events.id
  and rsvps.user_id is not null
  and rsvps.status = 'going'
group by events.id, events.title
order by events.id;

-- 6. Events whose attendee count changes when legacy-only rows are excluded.
with event_counts as (
  select
    events.id as event_id,
    events.title,
    count(rsvps.id) filter (
      where rsvps.status = 'going'
    )::integer as previous_going_count,
    count(rsvps.id) filter (
      where rsvps.user_id is not null
        and rsvps.status = 'going'
    )::integer as authenticated_going_count,
    count(rsvps.id) filter (
      where rsvps.user_id is null
        and rsvps.status = 'going'
    )::integer as excluded_legacy_going_count
  from public.events as events
  left join public.event_rsvps as rsvps
    on rsvps.event_id = events.id
  group by events.id, events.title
)
select
  event_counts.event_id,
  event_counts.title,
  event_counts.previous_going_count,
  event_counts.authenticated_going_count as quarantined_going_count,
  event_counts.excluded_legacy_going_count,
  event_counts.previous_going_count
    - event_counts.authenticated_going_count as attendee_count_change
from event_counts
where event_counts.previous_going_count
  is distinct from event_counts.authenticated_going_count
order by event_counts.event_id;
