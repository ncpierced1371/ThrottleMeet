-- Normalize RSVP data so each anonymous device can store one RSVP per event.
--
-- WARNING: The RPC grants in this migration are temporary no-auth MVP behavior.
-- A caller-provided participant_id is not an authentication boundary and can be
-- spoofed. Replace it with auth.uid()-based ownership and RLS before real users.

create extension if not exists pgcrypto;

create table public.event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id text not null references public.events(id) on delete cascade,
  participant_id text not null,
  status text not null check (
    status in ('going', 'interested', 'notGoing')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_rsvps_event_participant_key unique (
    event_id,
    participant_id
  )
);

create index event_rsvps_event_status_idx
on public.event_rsvps (event_id, status);

alter table public.event_rsvps enable row level security;

comment on table public.event_rsvps is
  'TEMPORARY NO-AUTH MVP RSVP storage. Replace device participant IDs with authenticated user ownership before production.';

-- SECURITY DEFINER is used so anon clients can read the aggregate and their
-- requested RSVP projection without receiving direct access to RSVP rows.
create or replace function public.get_events_for_participant(
  participant_id text
)
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
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    events.id,
    events.title,
    events.description,
    events.location_name,
    events.host_name,
    events.start_time,
    events.end_time,
    (
      count(rsvps.id) filter (where rsvps.status = 'going')
    )::integer as attendee_count,
    max(rsvps.status) filter (
      where rsvps.participant_id = $1
    ) as rsvp_status,
    events.created_at
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
    events.created_at
  order by events.start_time;
$$;

comment on function public.get_events_for_participant(text) is
  'TEMPORARY NO-AUTH MVP RPC. Returns RSVP aggregates and the status associated with a caller-provided device participant ID.';

revoke execute on function public.get_events_for_participant(text) from public;
grant execute on function public.get_events_for_participant(text) to anon;

-- SECURITY DEFINER is used because event_rsvps intentionally has no direct anon
-- table policies. The participant ID remains spoofable until real auth exists.
create or replace function public.set_event_rsvp(
  event_id text,
  participant_id text,
  status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved_status text;
begin
  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  if $2 is null or pg_catalog.btrim($2) = '' then
    raise exception 'participant_id must not be empty'
      using errcode = '22023';
  end if;

  if $3 is null or $3 not in ('going', 'interested', 'notGoing') then
    raise exception 'invalid RSVP status: %', $3
      using errcode = '22023';
  end if;

  insert into public.event_rsvps as rsvp (
    event_id,
    participant_id,
    status
  )
  values ($1, $2, $3)
  on conflict on constraint event_rsvps_event_participant_key
  do update set
    status = excluded.status,
    updated_at = pg_catalog.now()
  returning rsvp.status into saved_status;

  return saved_status;
end;
$$;

comment on function public.set_event_rsvp(text, text, text) is
  'TEMPORARY NO-AUTH MVP RPC. Upserts an RSVP using a caller-provided device participant ID.';

revoke execute on function public.set_event_rsvp(text, text, text) from public;
grant execute on function public.set_event_rsvp(text, text, text) to anon;

-- Legacy public.events.rsvp_status, public.events.attendee_count, and existing
-- public.events policies intentionally remain unchanged during this pass.
