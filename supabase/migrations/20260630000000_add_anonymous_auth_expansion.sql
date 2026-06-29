-- Expand the Events + RSVP schema for Supabase anonymous Auth while keeping
-- the caller-provided participant ID path available for rollback.
--
-- SECURITY: participant_id remains spoofable because the legacy RPCs trust a
-- value supplied by the caller. Keep those RPCs only during the migration
-- window; the v2 RPCs below derive identity exclusively from auth.uid().

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Authenticated user profiles. Each row is owned by the auth.users row with the same id.';

create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

revoke execute on function public.set_profiles_updated_at() from public, anon;
grant execute on function public.set_profiles_updated_at() to authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_profiles_updated_at();

alter table public.events
  add column creator_id uuid references auth.users(id) on delete set null;

create index events_creator_id_idx
on public.events (creator_id)
where creator_id is not null;

alter table public.event_rsvps
  add column user_id uuid references auth.users(id) on delete cascade;

-- Authenticated RSVP rows use user_id and intentionally omit participant_id.
-- The legacy column and unique constraint remain available for old clients.
alter table public.event_rsvps
  alter column participant_id drop not null;

alter table public.event_rsvps
  add constraint event_rsvps_has_identity_check check (
    participant_id is not null or user_id is not null
  );

create unique index event_rsvps_event_user_key
on public.event_rsvps (event_id, user_id)
where user_id is not null;

comment on column public.events.creator_id is
  'Authenticated creator identity. Null is retained for legacy events during migration.';

comment on column public.event_rsvps.participant_id is
  'LEGACY INSECURE identity supplied by callers. Retained temporarily for rollback compatibility.';

comment on column public.event_rsvps.user_id is
  'Authenticated RSVP owner derived from auth.uid() by v2 RPCs.';

alter table public.profiles enable row level security;

-- Profiles are directly accessible only to their owner. Column grants prevent
-- clients from rewriting timestamps; the trigger owns updated_at maintenance.
revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant insert (id, display_name) on table public.profiles to authenticated;
grant update (display_name) on table public.profiles to authenticated;

create policy "profiles_authenticated_select_own"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

create policy "profiles_authenticated_insert_own"
on public.profiles
for insert
to authenticated
with check (id = (select auth.uid()));

create policy "profiles_authenticated_update_own"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Authenticated clients may read shared event fields and only their own direct
-- RSVP row. Mutations remain RPC-only, so no authenticated insert/update/delete
-- table privileges or policies are granted for these tables.
grant select on table public.events to authenticated;
grant select on table public.event_rsvps to authenticated;

create policy "events_authenticated_select"
on public.events
for select
to authenticated
using (true);

create policy "event_rsvps_authenticated_select_own"
on public.event_rsvps
for select
to authenticated
using (user_id = (select auth.uid()));

create or replace function public.create_event_with_creator_rsvp_v2(
  event_id text,
  title text,
  description text,
  location_name text,
  host_name text,
  start_time timestamptz,
  end_time timestamptz
)
returns jsonb
language plpgsql
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

  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  insert into public.events (
    id,
    title,
    description,
    location_name,
    host_name,
    start_time,
    end_time,
    creator_id
  )
  values ($1, $2, $3, $4, $5, $6, $7, caller_id);

  insert into public.event_rsvps as rsvp (
    event_id,
    user_id,
    status
  )
  values ($1, caller_id, 'going')
  on conflict (event_id, user_id) where user_id is not null
  do update set
    status = excluded.status,
    updated_at = pg_catalog.now();

  return pg_catalog.jsonb_build_object(
    'id', $1,
    'attendee_count', 1,
    'rsvp_status', 'going'
  );
end;
$$;

comment on function public.create_event_with_creator_rsvp_v2(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) is
  'Authenticated RPC. Atomically creates an owned event and a Going RSVP using auth.uid().';

revoke execute on function public.create_event_with_creator_rsvp_v2(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) from public, anon;

grant execute on function public.create_event_with_creator_rsvp_v2(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) to authenticated;

create or replace function public.set_event_rsvp_v2(
  event_id text,
  status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  saved_status text;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  if $2 is null or $2 not in ('going', 'interested', 'notGoing') then
    raise exception 'invalid RSVP status: %', $2
      using errcode = '22023';
  end if;

  insert into public.event_rsvps as rsvp (
    event_id,
    user_id,
    status
  )
  values ($1, caller_id, $2)
  on conflict (event_id, user_id) where user_id is not null
  do update set
    status = excluded.status,
    updated_at = pg_catalog.now()
  returning rsvp.status into saved_status;

  return saved_status;
end;
$$;

comment on function public.set_event_rsvp_v2(text, text) is
  'Authenticated RPC. Upserts the caller RSVP using auth.uid(); no identity argument is accepted.';

revoke execute on function public.set_event_rsvp_v2(text, text)
from public, anon;
grant execute on function public.set_event_rsvp_v2(text, text)
to authenticated;

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
      count(rsvps.id) filter (where rsvps.status = 'going')
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
  'Authenticated RPC. Returns Going attendee aggregates and only the auth.uid() caller RSVP projection.';

revoke execute on function public.get_events_for_current_user()
from public, anon;
grant execute on function public.get_events_for_current_user()
to authenticated;

-- The legacy get_events_for_participant, set_event_rsvp, and
-- create_event_with_creator_rsvp RPCs and their anon grants intentionally remain
-- unchanged for rollback. Their participant IDs are not secure identities.
