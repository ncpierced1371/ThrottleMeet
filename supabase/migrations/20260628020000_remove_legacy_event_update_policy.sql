-- Remove legacy direct event mutation privileges.
-- RSVP updates now go through public.set_event_rsvp and public.event_rsvps.

drop policy if exists "dev allow update events" on public.events;

revoke update, delete, truncate, references, trigger
on public.events
from anon;
