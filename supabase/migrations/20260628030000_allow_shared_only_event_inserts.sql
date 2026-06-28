-- New event inserts now contain shared event fields only. The normalized RSVP
-- state and attendee count are read from public.event_rsvps through
-- public.get_events_for_participant.
--
-- Keep the legacy column during rollout, but allow new clients to omit it.

alter table public.events
alter column rsvp_status drop not null;
