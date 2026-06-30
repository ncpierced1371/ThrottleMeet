-- Quarantine retained participant-based RSVP rows from authenticated v2
-- attendee calculations.
--
-- Legacy rows and functions remain available during the rollback window, but
-- get_events_for_current_user() treats only user_id-backed rows as authenticated
-- attendance. No legacy data is deleted or rewritten by this migration.

create or replace function public.get_events_for_current_user()
returns table (
  id text,
  title text,
  description text,
  location_name text,
  host_name text,
  start_time timestamptz,
  end_time timestamptz,
  attendee_count integer,
  rsvp_status text,
  created_at timestamptz,
  creator_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  return query
  select
    events.id,
    events.title,
    events.description,
    events.location_name,
    events.host_name,
    events.start_time,
    events.end_time,
    (
      count(rsvps.id) filter (
        where rsvps.user_id is not null
          and rsvps.status = 'going'
      )
    )::integer as attendee_count,
    max(rsvps.status) filter (
      where rsvps.user_id = caller_id
    ) as rsvp_status,
    events.created_at,
    events.creator_id
  from public.events as events
  left join public.event_rsvps as rsvps
    on rsvps.event_id = events.id
  group by
    events.id,
    events.title,
    events.description,
    events.location_name,
    events.host_name,
    events.start_time,
    events.end_time,
    events.created_at,
    events.creator_id
  order by events.start_time;
end;
$$;

comment on function public.get_events_for_current_user() is
  'Authenticated RPC. Returns auth.uid()-specific RSVP status and counts only user_id-backed Going RSVPs. Retained legacy participant rows are excluded from v2 attendance.';

-- Preserve the post-cutoff execution boundary explicitly.
revoke execute on function public.get_events_for_current_user()
from public, anon;
grant execute on function public.get_events_for_current_user()
to authenticated;
