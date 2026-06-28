-- ThrottleMeet MVP events schema.
--
-- WARNING: The anon policies below are intentionally permissive for local
-- MVP/development use only. They must be replaced with authenticated,
-- ownership-aware policies before the app is used by real users.

create table if not exists public.events (
  id text primary key,
  title text not null,
  description text not null,
  location_name text not null,
  host_name text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  attendee_count integer not null default 0,
  rsvp_status text not null check (
    rsvp_status in ('going', 'interested', 'notGoing')
  ),
  created_at timestamptz not null default now()
);

alter table public.events enable row level security;

-- RLS policies do not grant table privileges by themselves. These grants are
-- intentionally limited to the three operations used by the current MVP.
grant select, insert, update on table public.events to anon;

-- TEMPORARY DEV POLICY: public event reads for the unauthenticated MVP.
create policy "events_dev_anon_select"
on public.events
for select
to anon
using (true);

-- TEMPORARY DEV POLICY: unrestricted event creation for the unauthenticated MVP.
create policy "events_dev_anon_insert"
on public.events
for insert
to anon
with check (true);

-- TEMPORARY DEV POLICY: unrestricted event updates for the unauthenticated MVP.
-- This currently supports the denormalized RSVP field and is not safe for real users.
create policy "events_dev_anon_update"
on public.events
for update
to anon
using (true)
with check (true);
