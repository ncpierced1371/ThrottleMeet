# Throttle Meet Controlled Beta Scope

## Purpose

This document defines the approved scope for the current controlled beta. The
working Flutter application and deployed Supabase schema are the source of
truth. Older planning documents remain useful as roadmap input, but they do not
expand this beta automatically.

The controlled beta validates one narrow product loop:

> Discover an event, create and manage an owned event, and maintain an
> authenticated-user-specific RSVP reliably across normal and degraded network
> conditions.

## 1. Current Working Capabilities

### Authentication and Profiles

- Bootstrap an anonymous Supabase Auth user when no session exists.
- Restore an existing Supabase session on later launches.
- Require an authenticated Supabase user before creating the Events controller
  or loading user-specific event data.
- Create or load the authenticated user's `public.profiles` row.
- Treat profile synchronization as secondary readiness: profile failure is
  reported separately and does not block authenticated event access.
- Retry profile synchronization without repeating anonymous sign-in or
  recreating the Events controller.
- Recreate user-scoped event state when the authenticated user ID changes.

### Events and Ownership

- View an event list and event details.
- Create events with title, description, host, location name, and start/end
  times.
- Create the event, authenticated `creator_id`, and creator's `going` RSVP
  atomically through `create_event_with_creator_rsvp_v2`.
- Project `is_owner` from `auth.uid()` rather than trusting caller-supplied
  identity.
- Show Edit and Cancel controls only for an owned active event.
- Edit shared event fields through the owner-only `update_event_v2` RPC.
- Soft-cancel an event through the owner-only, idempotent `cancel_event_v2`
  RPC.
- Keep cancelled events visible with a cancelled indicator.
- Disable edit, cancel, and RSVP controls after cancellation.
- Keep ownerless legacy events readable but not editable or cancellable.
- Refresh events manually and after successful mutations.
- Preserve previously accepted event state when a write succeeds but the
  follow-up refresh fails, and report the operation as incomplete.
- Ignore stale responses from superseded refresh requests.

### RSVP

- Set the authenticated user's RSVP to `going`, `interested`, or `notGoing`.
- Maintain one authenticated RSVP per event and user.
- Derive RSVP identity only from `auth.uid()` through `set_event_rsvp_v2`.
- Return only the current authenticated user's RSVP projection.
- Count only authenticated `user_id` rows with `going` status in the v2
  attendee total.
- Reject RSVP changes for cancelled events.
- Confirm RPC responses before reporting mutation success.

### Persistence and Reliability

- Cache only successful authenticated-user-aware event snapshots in
  SharedPreferences.
- Namespace every snapshot by the authenticated Supabase user ID.
- Never reuse legacy participant-keyed snapshots automatically.
- Show cached events before attempting remote refresh.
- Mark cached data with `Showing saved events`.
- Replace cached data only after the controller accepts the latest remote
  response.
- Keep cached events visible when remote refresh fails.
- Allow cached event startup when profile synchronization is offline, provided
  an authenticated session is available.
- Apply request timeouts to Supabase repository operations.
- Distinguish network, timeout, authorization, validation/server, and unknown
  failures.
- Keep profile errors separate from event loading and mutation errors.
- Show loading, empty, error, saved-data, and retry states.

### Security and Migration State

- Use authenticated v2 event RPCs:
  `get_events_for_current_user`, `create_event_with_creator_rsvp_v2`,
  `set_event_rsvp_v2`, `update_event_v2`, and `cancel_event_v2`.
- Derive all active event and RSVP identity from `auth.uid()`.
- Deny anonymous execution of legacy participant-based RPCs.
- Deny anonymous direct event reads.
- Deny authenticated direct event and RSVP mutations; writes remain RPC-only.
- Retain legacy participant columns, rows, and functions temporarily for
  rollback and inventory without using them as the active application path.
- Exclude retained participant-only RSVP rows from authenticated attendee
  counts.
- Preserve normalized RSVP storage in `public.event_rsvps`.

### Architecture and Validation

- Use a Flutter feature-first structure with data, domain, and presentation
  layers.
- Route UI actions through controllers and repositories; event screens contain
  no direct Supabase calls.
- Keep Supabase/Postgres as the remote source of truth and snapshots as a
  read-only reliability layer.
- Maintain versioned migrations and transaction-wrapped SQL verification
  scripts for auth, RSVP, security cutoff, legacy quarantine, and lifecycle
  behavior.
- Cover repositories with mocked transport and controllers/UI with offline
  fakes.
- Pass `flutter analyze` and all 84 current Flutter tests.
- Provide a non-developer beta procedure in
  [BETA_SMOKE_TEST.md](BETA_SMOKE_TEST.md).

## 2. Controlled-Beta Scope

The controlled beta includes only:

1. Anonymous Supabase Auth bootstrap and session restoration.
2. Non-blocking authenticated profile synchronization.
3. Event discovery through the current list and detail screens.
4. Authenticated event creation with creator ownership and automatic Going
   RSVP.
5. Authenticated-user-specific RSVP creation and changes.
6. Going-attendee aggregation from authenticated RSVP rows.
7. Owner-only event editing.
8. Owner-only soft cancellation and cancelled-event read-only behavior.
9. Supabase persistence through authenticated v2 RPCs.
10. Read-only authenticated snapshot recovery for degraded-network startup.
11. Typed errors, timeouts, retry states, mutation refresh semantics, and
    refresh race protection.
12. Flutter regression tests, SQL verification, and the manual beta smoke-test
    checklist.

This beta is for a small, known, trusted tester group. It is not an open or
public launch. Feedback should focus on whether authentication, event creation,
discovery, ownership, RSVP, editing, cancellation, and degraded-network reads
are understandable and reliable.

## 3. Explicitly Deferred Features

The following remain outside the controlled-beta scope:

- Map pins, route building, navigation, and location tracking.
- Event chat and direct messaging.
- Convoy coordination and live participant locations.
- Offline event creation, offline RSVP writes, offline edits/cancellation,
  outbox processing, or optimistic writes.
- Social feed, groups, friends, reactions, photos, or video.
- Parts/services marketplace and seller tools.
- Payments, subscriptions, commissions, sponsorships, and other monetization.
- OBD-II and vehicle diagnostics.
- AR navigation.
- Live streaming.
- Event scraping, aggregation, deduplication, and external event imports.
- EV charging and route intelligence.
- Organizer/admin web portal.
- AI recommendations and social intelligence.
- QR check-in, Apple Wallet, CarPlay, Watch, widgets, and Live Activities.
- Voice communication and emergency broadcast systems.
- Public-beta or open-registration launch.

Map, Chat, and Convoy remain later beta phases. Social, marketplace,
monetization, OBD-II, and AR remain future roadmap items rather than controlled
beta prerequisites.

## 4. Public-Beta Blockers

The authenticated controlled-beta architecture removes several earlier
blockers, but it is not sufficient for public beta. Throttle Meet must not move
to public beta until all of the following are complete:

- Replace device-bound anonymous-only identity with a user-manageable account
  lifecycle or documented upgrade/recovery path.
- Add deliberate sign-out, session expiry, account recovery, and
  authenticated-user-change UX.
- Define profile editing, account deletion, and associated data-retention
  behavior.
- Complete privacy policy, terms, consent, and deletion documentation that
  matches implemented behavior.
- Add abuse prevention, rate limiting, spam controls, and a moderation/reporting
  process for user-created events.
- Add production crash/error monitoring, operational alerting, backup
  verification, and a tested rollback process.
- Complete security review of every `SECURITY DEFINER` RPC, RLS policy, grant,
  and migration in the deployed public-beta environment.
- Inventory and deliberately migrate, archive, or remove retained legacy
  participant identities after the rollback window closes.
- Define snapshot retention, maximum age, privacy expectations, and deletion on
  sign-out/account change.
- Pass physical-device, multi-user, offline/recovery, SQL security, and manual
  lifecycle smoke tests against the release environment.
- Resolve all critical and high-severity security, privacy, data-integrity, and
  operational issues.

Public beta remains explicitly deferred even though event and RSVP ownership
now use authenticated `auth.uid()` identities.

## 5. Current Architecture Decisions

- Continue the current Flutter project; do not restart or rewrite it.
- Flutter and Supabase are the active stack. SwiftUI, SwiftData, CloudKit, and
  custom Node/AWS architecture from older plans are not current requirements.
- Supabase anonymous Auth is the controlled-beta identity source.
- Active event repositories do not use `ParticipantIdStore`; retained
  participant identity code exists only for legacy rollback compatibility.
- Supabase/Postgres remains the remote source of truth.
- Authenticated v2 RPCs derive identity from `auth.uid()` and accept no caller
  identity fields.
- `event_rsvps` remains the canonical normalized RSVP table. Do not rename it
  merely to match older documents that use `event_attendees`.
- Participant-only legacy RSVP rows remain stored temporarily but are excluded
  from authenticated v2 counts.
- SharedPreferences snapshots are keyed by authenticated user ID and are a
  read-only reliability layer, not a second source of truth.
- Profile synchronization is secondary readiness; authenticated event loading
  does not wait for profile success.
- The controller accepts only the latest refresh result and writes only
  accepted snapshots.
- Remote mutations remain server-first. No offline write claims are made.
- Event creation uses a transactional event-plus-creator-RSVP RPC.
- Event edits and soft cancellation are owner-only RPC operations.
- Cancelled events remain visible and read-only; hard deletion and restoration
  are not part of this beta.
- Typed application errors isolate controllers and UI from Supabase SDK error
  details.
- Environment values are supplied through `SUPABASE_URL` and `SUPABASE_KEY`
  compile-time definitions rather than hardcoded credentials.
- Seed data is restricted to in-memory development/testing and is never a
  production fallback.

## 6. Known Limitations

- Anonymous Auth users are still device/session-bound and have no user-managed
  recovery, account upgrade, or sign-out experience.
- Profile synchronization exists, but profile editing and broader profile UX do
  not.
- Ownerless legacy events remain readable and intentionally cannot be edited or
  cancelled.
- Legacy participant columns, rows, functions, and rollback code remain in the
  repository even though anonymous grants are cut off and the app uses v2 RPCs.
- Cancelled events cannot be restored or hard-deleted through the app.
- Events have a location name but no coordinates or map experience.
- Discovery has no categories, search, filtering, or pagination.
- There is no event chat, convoy system, or social feed.
- Writes cannot be queued offline.
- Timed-out writes have an ambiguous server outcome because a Dart timeout does
  not cancel an in-flight HTTP request.
- Cached snapshots have no maximum age and are stored unencrypted in
  SharedPreferences.
- Cache write failures are best-effort and currently visible only in debug
  logging.
- Environment separation depends on supplying the correct compile-time values;
  there is no in-app environment selector.
- The latest migrations and repair functions must be deployed and verified in
  every beta environment; source presence alone does not prove deployment.
- Passing automated tests does not replace physical-device, multi-user, offline,
  RLS, grant, and SQL verification.
- Public legal, abuse-response, monitoring, and account-deletion operations are
  not yet complete.

## 7. Next Implementation Sequence

1. Deploy every current migration, including lifecycle and RSVP repair
   migrations, to the controlled-beta Supabase project.
2. Run authenticated auth/RSVP, security-cutoff, legacy-quarantine, and
   lifecycle SQL verification against that deployed environment.
3. Execute [BETA_SMOKE_TEST.md](BETA_SMOKE_TEST.md) with two independent
   authenticated sessions and record results.
4. Add explicit auth lifecycle UX and tests for session expiry, sign-out, user
   changes, and recovery or account upgrade.
5. Add basic profile editing and define account/profile deletion behavior.
6. Inventory legacy ownerless events and participant-only RSVP data, then plan
   a reviewed cleanup migration after the rollback window.
7. Add beta operations: crash/error monitoring, release identifiers, alerting,
   backup checks, rollback notes, and tester issue intake.
8. Add privacy, terms, consent, retention, and deletion documentation matching
   the shipped app.
9. Add narrow abuse prevention and rate limits for event creation and mutation
   RPCs before expanding tester access.
10. Re-audit security and controlled-beta evidence, resolve critical/high
    findings, and make a separate decision about any future public beta.

Only after the Events + RSVP controlled beta is stable should product work move
to later phases: Map and external navigation, RSVP-gated Chat, then Convoy and
live location sharing. Social, marketplace, monetization, OBD-II, and AR remain
further deferred.
