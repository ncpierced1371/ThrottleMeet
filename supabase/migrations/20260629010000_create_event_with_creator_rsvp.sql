-- Create an event and its creator RSVP atomically.
--
-- WARNING: This remains temporary no-auth MVP behavior. The caller-provided
-- participant_id is not a security boundary and can be spoofed. Replace it
-- with auth.uid()-based ownership before use with untrusted users.

create or replace function public.create_event_with_creator_rsvp(
  event_id text,
  title text,
  description text,
  location_name text,
  host_name text,
  start_time timestamptz,
  end_time timestamptz,
  participant_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if $1 is null or pg_catalog.btrim($1) = '' then
    raise exception 'event_id must not be empty'
      using errcode = '22023';
  end if;

  if $8 is null or pg_catalog.btrim($8) = '' then
    raise exception 'participant_id must not be empty'
      using errcode = '22023';
  end if;

  insert into public.events (
    id,
    title,
    description,
    location_name,
    host_name,
    start_time,
    end_time
  )
  values ($1, $2, $3, $4, $5, $6, $7);

  insert into public.event_rsvps as rsvp (
    event_id,
    participant_id,
    status
  )
  values ($1, $8, 'going')
  on conflict on constraint event_rsvps_event_participant_key
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

comment on function public.create_event_with_creator_rsvp(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text
) is
  'TEMPORARY NO-AUTH MVP RPC. Atomically creates an event and a Going RSVP for a caller-provided participant ID.';

revoke execute on function public.create_event_with_creator_rsvp(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text
) from public;

grant execute on function public.create_event_with_creator_rsvp(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text
) to anon;

-- Event creation now goes through the transactional RPC above.
drop policy if exists "events_dev_anon_insert" on public.events;
revoke insert on table public.events from anon;
