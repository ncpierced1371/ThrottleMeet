-- Security cutoff after the Flutter client transition to authenticated v2 RPCs.
--
-- The legacy functions remain defined for an emergency rollback, but no API
-- client role may execute them anonymously. Do not restore these grants after
-- the rollback window closes; caller-provided participant IDs are spoofable.

revoke execute on function public.get_events_for_participant(text)
from public, anon;

revoke execute on function public.set_event_rsvp(text, text, text)
from public, anon;

revoke execute on function public.create_event_with_creator_rsvp(
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text
)
from public, anon;

comment on function public.get_events_for_participant(text) is
  'LEGACY DISABLED RPC. Retained temporarily for rollback only; caller-provided participant IDs are insecure.';

comment on function public.set_event_rsvp(text, text, text) is
  'LEGACY DISABLED RPC. Retained temporarily for rollback only; caller-provided participant IDs are insecure.';

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
  'LEGACY DISABLED RPC. Retained temporarily for rollback only; caller-provided participant IDs are insecure.';

-- Events are now read through get_events_for_current_user(). Remove the old
-- anonymous table access and both policy names used by historical schemas.
revoke select, insert, update, delete on table public.events from public, anon;

drop policy if exists "events_dev_anon_select" on public.events;
drop policy if exists "dev allow read events" on public.events;

-- Clean up the dormant permissive update policies as part of the cutoff.
drop policy if exists "events_dev_anon_update" on public.events;
drop policy if exists "dev allow update events" on public.events;

-- Authenticated grants, RLS policies, profiles, and the v2 RPCs intentionally
-- remain unchanged. The authenticated role continues to execute:
--   get_events_for_current_user()
--   create_event_with_creator_rsvp_v2(...)
--   set_event_rsvp_v2(text, text)
