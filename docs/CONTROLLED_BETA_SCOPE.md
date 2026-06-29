# ThrottleMeet Controlled Beta Scope

## Purpose

This document defines the approved scope for the current controlled beta. The
working Flutter and Supabase implementation is the source of truth. Older
planning documents remain useful as roadmap input, but they do not expand this
beta automatically.

The controlled beta is intended to validate one narrow product loop:

> Discover an event, create an event, and manage a participant-specific RSVP
> reliably across normal and degraded network conditions.

## 1. Current Working Capabilities

### Events

- View an event list and event details.
- Create events with title, description, host, location name, and start/end
  times.
- Create the event and creator's `going` RSVP atomically through a Supabase RPC.
- Refresh events manually and after successful mutations.
- Preserve previously accepted event state when refreshes fail.
- Ignore stale responses from superseded refresh requests.

### RSVP

- Set RSVP status to `going`, `interested`, or `notGoing`.
- Maintain one RSVP per event/participant through a database uniqueness
  constraint and upsert RPC.
- Return participant-specific RSVP status without exposing all RSVP rows.
- Aggregate attendee count from `going` RSVP records.
- Confirm RPC responses before reporting mutation success.

### Persistence and Reliability

- Persist a stable anonymous participant ID locally.
- Cache successful participant-aware event snapshots in SharedPreferences.
- Namespace snapshots by participant ID.
- Show cached events before attempting remote refresh.
- Mark cached data with a small "Showing saved events" indicator.
- Replace cached data only after the controller accepts the latest remote
  response.
- Keep cached events visible when remote refresh fails.
- Apply request timeouts to Supabase repository operations.
- Distinguish network, timeout, authorization, validation/server, and unknown
  failures.
- Show user-appropriate loading, empty, error, and retry states.

### Architecture and Validation

- Flutter feature-first structure with data, domain, and presentation layers.
- UI calls controllers; controllers call repositories; repositories coordinate
  Supabase and local snapshots.
- No direct Supabase calls from event screens.
- Versioned Supabase migrations and normalized RSVP storage.
- Offline repository/controller/widget tests using fakes and mocked transport.
- SQL verification coverage for normalized RSVP behavior.

## 2. Controlled-Beta Scope

The controlled beta includes only:

1. Event discovery through the current event list.
2. Event detail viewing.
3. Event creation.
4. Creator automatically becoming `going`.
5. Participant-specific RSVP creation and changes.
6. Going-attendee aggregation.
7. Supabase persistence.
8. Read-only saved event snapshots for degraded-network startup and refresh.
9. Typed errors, timeouts, retry states, and refresh race protection.
10. Regression, repository contract, and database verification tests.

This beta is for a small, known, trusted tester group. It is not an open or
public launch. Beta feedback should focus on whether event creation, discovery,
and RSVP behavior are useful, understandable, and reliable.

## 3. Explicitly Deferred Features

The following are outside the current controlled-beta scope:

- Map pins, route building, navigation, and location tracking.
- Event chat and direct messaging.
- Convoy coordination and live participant locations.
- Offline event creation, offline RSVP writes, outbox processing, or optimistic
  writes.
- Social feed, groups, friends, reactions, photos, or video.
- Live streaming.
- Event scraping, aggregation, deduplication, and external event imports.
- AR navigation.
- OBD-II and vehicle diagnostics.
- EV charging and route intelligence.
- Parts/services marketplace and seller tools.
- Organizer/admin web portal.
- Payments, subscriptions, commissions, sponsorships, and other monetization.
- AI recommendations and social intelligence.
- QR check-in, Apple Wallet, CarPlay, Watch, widgets, and Live Activities.
- Voice communication and emergency broadcast systems.

Map, Chat, and Convoy remain later beta phases. They are not prerequisites for
testing the current Events + RSVP hypothesis.

## 4. Public-Beta Blockers

ThrottleMeet must not move to public beta until all of the following are true:

- Supabase Auth provides trusted user identity and session handling.
- Event and RSVP ownership is based on `auth.uid()` rather than caller-provided
  participant IDs.
- RLS uses least-privilege ownership policies and denies unauthorized writes.
- Anonymous event creation and spoofable RSVP access are removed.
- Event creators can safely manage only their own events.
- Development, beta, and production configuration are separated.
- Privacy policy, terms, and data deletion behavior are published and match the
  implemented product.
- Production error/crash monitoring and an operational rollback process exist.
- Physical-device smoke testing and security/RLS validation pass.
- Sensitive cached data and retention expectations have been reviewed.

The current anonymous participant ID is a temporary controlled-beta mechanism,
not an authentication or authorization boundary.

## 5. Current Architecture Decisions

- Continue the current Flutter project; do not restart or rebuild it from
  scratch.
- Flutter and Supabase are the active stack. SwiftUI, SwiftData, CloudKit, and
  custom Node/AWS architecture from older plans are not current requirements.
- Supabase/Postgres remains the remote source of truth.
- `event_rsvps` remains the canonical normalized RSVP table. Do not rename it
  merely to match older documents that use `event_attendees`.
- SharedPreferences snapshots are a read-only reliability layer, not a second
  source of truth.
- The controller accepts only the latest refresh result and commits only
  accepted snapshots.
- Remote writes remain server-first. No offline write claims are made.
- Multi-table event creation uses a transactional RPC.
- Typed application errors isolate controllers and UI from Supabase SDK error
  details.
- The current controller/repository boundary is sufficient for this scope. Do
  not add architectural layers solely to mirror old planning diagrams.
- Seed data is restricted to in-memory development/testing and is never a
  production fallback.

## 6. Known Limitations

- Participant IDs are locally generated and spoofable.
- There is no Auth or Profile feature yet.
- Events have a location name but no coordinates or map experience.
- Event owners cannot edit, cancel, or manage lifecycle state.
- Discovery has no categories, search, filtering, or pagination.
- There is no event chat or convoy system.
- Writes cannot be queued offline.
- Timed-out writes have an ambiguous server outcome because a Dart timeout does
  not cancel an in-flight HTTP request.
- Cached snapshots have no maximum age and are stored unencrypted in
  SharedPreferences.
- Cache write failures are best-effort and currently visible only in debug
  logging.
- Supabase configuration is currently tied to one configured project.
- The latest migrations must be deployed and verified in each beta environment;
  source presence alone does not prove deployment.
- The public legal and deletion pages described in planning material are not
  part of this repository.

## 7. Next Implementation Sequence

1. Add separate development and controlled-beta Supabase configuration.
2. Deploy all current migrations to the beta project and run RSVP/RPC/RLS
   verification against that environment.
3. Complete a physical-device Events + RSVP smoke test and record known beta
   limitations.
4. Add minimal Supabase Auth with session persistence.
5. Add a basic Profile model and profile bootstrap flow.
6. Replace participant-ID ownership with `auth.uid()` in event and RSVP RPCs.
7. Implement least-privilege RLS for authenticated event creation and RSVP
   ownership.
8. Add event creator ownership, lifecycle status, and owner-only edit/cancel
   behavior.
9. Add focused discovery improvements: categories, date filters, text search,
   and pagination.
10. Add beta operations: privacy/terms/deletion pages, crash/error monitoring,
    rollback notes, tester guidance, and a release checklist.

After the controlled beta validates the Events + RSVP loop, plan later phases
in this order: Map and external navigation, RSVP-gated Chat, then Convoy and
live location sharing.
