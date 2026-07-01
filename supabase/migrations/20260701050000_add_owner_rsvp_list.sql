-- Add a narrow owner-only read path for authenticated event RSVP details.
--
-- Profile rows remain private through their existing self-access RLS policies.
-- This SECURITY DEFINER function exposes only the display fields needed by an
-- authenticated event owner and never returns auth.users metadata.

create function public.get_event_rsvps_for_owner_v1(event_id text)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  status text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target_creator_id uuid;
begin
  if caller_id is null then
    raise exception 'authentication required'
      using errcode = '42501';
  end if;

  select events_row.creator_id
  into target_creator_id
  from public.events as events_row
  where events_row.id = $1;

  if not found then
    raise exception 'event not found: %', $1
      using errcode = 'P0002';
  end if;

  if target_creator_id is null then
    raise exception 'ownerless events do not expose an RSVP list'
      using errcode = '42501';
  end if;

  if target_creator_id <> caller_id then
    raise exception 'only the event owner may view the RSVP list'
      using errcode = '42501';
  end if;

  return query
  select
    rsvps.user_id,
    profiles.display_name,
    profiles.avatar_url,
    rsvps.status,
    rsvps.updated_at
  from public.event_rsvps as rsvps
  left join public.profiles as profiles
    on profiles.id = rsvps.user_id
  where rsvps.event_id = $1
    and rsvps.user_id is not null
  order by
    case rsvps.status
      when 'going' then 1
      when 'interested' then 2
      when 'notGoing' then 3
      else 4
    end,
    profiles.display_name nulls last,
    rsvps.user_id;
end;
$$;

comment on function public.get_event_rsvps_for_owner_v1(text) is
  'Authenticated owner-only RPC returning user_id-backed RSVP status and limited profile display fields. Legacy participant-only rows and auth metadata are excluded.';

revoke execute on function public.get_event_rsvps_for_owner_v1(text)
from public, anon;
grant execute on function public.get_event_rsvps_for_owner_v1(text)
to authenticated;
