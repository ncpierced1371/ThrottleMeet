-- Relax legacy event RSVP/count columns now that participant RSVP data lives in
-- public.event_rsvps and app writes no longer send these fields.
--
-- These columns remain temporarily for backward compatibility and should be
-- removed in a later cleanup migration.

alter table public.events
  alter column rsvp_status drop not null;

alter table public.events
  alter column attendee_count drop not null;
