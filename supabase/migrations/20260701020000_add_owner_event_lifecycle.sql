-- Add an authenticated, owner-only lifecycle for events.
--
-- Legacy ownerless events remain readable but intentionally cannot be edited
-- or cancelled. Event mutations stay behind SECURITY DEFINER RPCs; no direct
-- table mutation privileges are granted to API roles.

alter table public.events
  add column status text not null default 'active',
  add column cancelled_at timestamptz,
  add column updated_at timestamptz not null default now(),
  add constraint events_status_check check (
    status in ('active', 'cancelled')
  );

comment on column public.events.status is
  'Lifecycle state. Events are retained when cancelled rather than deleted.';

comment on column public.events.cancelled_at is
  'Time an authenticated owner cancelled the event; null while active.';

comment on column public.events.updated_at is
  'Time shared event fields or lifecycle state were last changed.';

-- Preserve RPC-only mutation access even if an earlier environment acquired a
-- stale authenticated table grant. SECURITY DEFINER RPCs run as their owner.
revoke insert, update, delete on table public.events from authenticated;

-- PostgreSQL cannot replace a table-returning function while changing its
-- output columns, so recreate the projection inside this migration transaction.
drop function public.get_events_for_current_user();

create function public.get_events_for_current_user()
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
  creator_id uuid,
  status text,
  cancelled_at timestamptz,
  is_owner boolean
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
    events.creator_id,
    events.status,
    events.cancelled_at,
    (events.creator_id = caller_id) is true as is_owner
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
    events.creator_id,
    events.status,
    events.cancelled_at
  order by events.start_time;
end;
$$;

comment on function public.get_events_for_current_user() is
  'Authenticated RPC. Returns lifecycle and caller ownership, auth.uid()-specific RSVP status, and user_id-backed Going counts.';

revoke execute on function public.get_events_for_current_user()
from public, anon;
grant execute on function public.get_events_for_current_user()
to authenticated;

-- Keep the established PostgREST parameter names because they are part of the
-- Flutter RPC payload contract. The compiler directive resolves bare names in
-- INSERT and ON CONFLICT column lists as columns; values remain positional.
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
#variable_conflict use_column
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

create function public.update_event_v2(
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
#variable_conflict use_column
declare
  caller_id uuid := auth.uid();
  target_creator_id uuid;
  target_status text;
  saved_updated_at timestamptz;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  if $2 is null or pg_catalog.btrim($2) = '' then
    raise exception 'title must not be empty'
      using errcode = '22023';
  end if;

  if $3 is null or pg_catalog.btrim($3) = '' then
    raise exception 'description must not be empty'
      using errcode = '22023';
  end if;

  if $4 is null or pg_catalog.btrim($4) = '' then
    raise exception 'location_name must not be empty'
      using errcode = '22023';
  end if;

  if $5 is null or pg_catalog.btrim($5) = '' then
    raise exception 'host_name must not be empty'
      using errcode = '22023';
  end if;

  if $6 is null then
    raise exception 'start_time must not be null'
      using errcode = '22023';
  end if;

  if $7 is null then
    raise exception 'end_time must not be null'
      using errcode = '22023';
  end if;

  if $7 <= $6 then
    raise exception 'end_time must be after start_time'
      using errcode = '22023';
  end if;

  select events.creator_id, events.status
  into target_creator_id, target_status
  from public.events as events
  where events.id = $1
  for update;

  if not found then
    raise exception 'event not found: %', $1
      using errcode = 'P0002';
  end if;

  if target_creator_id is null then
    raise exception 'ownerless events cannot be edited'
      using errcode = '42501';
  end if;

  if target_creator_id <> caller_id then
    raise exception 'only the event owner may edit this event'
      using errcode = '42501';
  end if;

  if target_status = 'cancelled' then
    raise exception 'cancelled events cannot be edited'
      using errcode = '22023';
  end if;

  update public.events as events
  set
    title = $2,
    description = $3,
    location_name = $4,
    host_name = $5,
    start_time = $6,
    end_time = $7,
    updated_at = pg_catalog.now()
  where events.id = $1
  returning events.updated_at into saved_updated_at;

  return pg_catalog.jsonb_build_object(
    'id', $1,
    'title', $2,
    'description', $3,
    'location_name', $4,
    'host_name', $5,
    'start_time', $6,
    'end_time', $7,
    'updated_at', saved_updated_at
  );
end;
$$;

comment on function public.update_event_v2(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) is
  'Authenticated owner-only RPC. Updates editable fields on an active event using auth.uid().';

revoke execute on function public.update_event_v2(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) from public, anon;

grant execute on function public.update_event_v2(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) to authenticated;

create function public.cancel_event_v2(event_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller_id uuid := auth.uid();
  target_creator_id uuid;
  target_status text;
  saved_cancelled_at timestamptz;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  select events.creator_id, events.status, events.cancelled_at
  into target_creator_id, target_status, saved_cancelled_at
  from public.events as events
  where events.id = $1
  for update;

  if not found then
    raise exception 'event not found: %', $1
      using errcode = 'P0002';
  end if;

  if target_creator_id is null then
    raise exception 'ownerless events cannot be cancelled'
      using errcode = '42501';
  end if;

  if target_creator_id <> caller_id then
    raise exception 'only the event owner may cancel this event'
      using errcode = '42501';
  end if;

  if target_status = 'active' then
    update public.events as events
    set
      status = 'cancelled',
      cancelled_at = pg_catalog.now(),
      updated_at = pg_catalog.now()
    where events.id = $1
    returning events.cancelled_at into saved_cancelled_at;
  end if;

  return pg_catalog.jsonb_build_object(
    'id', $1,
    'status', 'cancelled',
    'cancelled_at', saved_cancelled_at
  );
end;
$$;

comment on function public.cancel_event_v2(text) is
  'Authenticated owner-only RPC. Idempotently marks an event cancelled using auth.uid(); the event is retained.';

revoke execute on function public.cancel_event_v2(text)
from public, anon;
grant execute on function public.cancel_event_v2(text)
to authenticated;

-- Keep the existing authenticated RSVP contract, but lock and verify the
-- target event first so an RSVP cannot race past a committed cancellation.
create or replace function public.set_event_rsvp_v2(
  event_id text,
  status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller_id uuid := auth.uid();
  event_status text;
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

  select events.status
  into event_status
  from public.events as events
  where events.id = $1
  for share;

  if not found then
    raise exception 'event not found: %', $1
      using errcode = 'P0002';
  end if;

  if event_status = 'cancelled' then
    raise exception 'cancelled events cannot receive RSVP changes'
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
  'Authenticated RPC. Upserts the auth.uid() caller RSVP for an active event and rejects cancelled events.';

revoke execute on function public.set_event_rsvp_v2(text, text)
from public, anon;
grant execute on function public.set_event_rsvp_v2(text, text)
to authenticated;
