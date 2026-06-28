-- RSVP updates no longer mutate public.events.rsvp_status directly.
-- They now go through public.set_event_rsvp and are stored in
-- public.event_rsvps, so anonymous clients no longer need UPDATE access to
-- shared event rows.

drop policy if exists "events_dev_anon_update" on public.events;

revoke update on table public.events from anon;

-- Anonymous SELECT and INSERT access on public.events intentionally remain
-- unchanged for the current MVP.
