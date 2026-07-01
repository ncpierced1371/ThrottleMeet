-- Replace authenticated v2 RSVP writes with explicit update-then-insert logic.
--
-- Public argument names remain unchanged because PostgREST uses them as part
-- of the RPC contract. No tables, policies, or direct grants are changed.

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
  desired_status text := 'going';
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

  update public.event_rsvps
  set
    status = desired_status,
    updated_at = pg_catalog.now()
  where public.event_rsvps.event_id = $1
    and public.event_rsvps.user_id = caller_id;

  if not found then
    insert into public.event_rsvps (
      event_id,
      user_id,
      status
    )
    values ($1, caller_id, desired_status);
  end if;

  return pg_catalog.jsonb_build_object(
    'id', $1,
    'attendee_count', 1,
    'rsvp_status', desired_status
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
  'Authenticated RPC. Atomically creates an owned event and a Going RSVP using auth.uid() and explicit update-then-insert logic.';

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
  desired_status text := $2;
  event_status text;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  if desired_status is null
    or desired_status not in ('going', 'interested', 'notGoing') then
    raise exception 'invalid RSVP status: %', desired_status
      using errcode = '22023';
  end if;

  select events_row.status
  into event_status
  from public.events as events_row
  where events_row.id = $1
  for share;

  if not found then
    raise exception 'event not found: %', $1
      using errcode = 'P0002';
  end if;

  if event_status = 'cancelled' then
    raise exception 'cancelled events cannot receive RSVP changes'
      using errcode = '22023';
  end if;

  update public.event_rsvps
  set
    status = desired_status,
    updated_at = pg_catalog.now()
  where public.event_rsvps.event_id = $1
    and public.event_rsvps.user_id = caller_id;

  if not found then
    insert into public.event_rsvps (
      event_id,
      user_id,
      status
    )
    values ($1, caller_id, desired_status);
  end if;

  return desired_status;
end;
$$;

comment on function public.set_event_rsvp_v2(text, text) is
  'Authenticated RPC. Updates or inserts the auth.uid() caller RSVP for an active event using explicit update-then-insert logic.';

revoke execute on function public.set_event_rsvp_v2(text, text)
from public, anon;
grant execute on function public.set_event_rsvp_v2(text, text)
to authenticated;
