# Throttle Meet Authenticated Beta Smoke Test

## Purpose

Use this checklist before inviting controlled-beta testers and after any beta
release. It verifies the current Events, RSVP, ownership, cancellation, and
saved-event behavior without requiring the tester to understand Flutter or
database implementation details.

Do not use production data for this test. Use the beta Supabase project and
events clearly named as smoke-test fixtures.

## Test Record

Record these details before starting:

- [ ] Tester name:
- [ ] Test date:
- [ ] App commit or build number:
- [ ] macOS version:
- [ ] Flutter version, if launching from source:
- [ ] Beta Supabase project name:
- [ ] Tester A anonymous user ID:
- [ ] Tester B anonymous user ID:
- [ ] Smoke-test event ID:
- [ ] Smoke-test event title:

Use two separate authenticated sessions for multi-user checks. Two Macs are
ideal. A second clean macOS user profile or a coordinator-provided test build
is also acceptable. Do not clear an existing tester's session unless the beta
coordinator has approved it.

## 1. Environment Setup

### Required values

Ask the beta coordinator for:

- `SUPABASE_URL`: the beta Supabase project URL.
- `SUPABASE_KEY`: the beta project's publishable or anonymous client key.

Do not post either value in screenshots, public issues, chat rooms, or source
control.

### Launch on macOS

From the project directory, replace the placeholders and run:

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL="<BETA_SUPABASE_URL>" \
  --dart-define=SUPABASE_KEY="<BETA_SUPABASE_KEY>"
```

Keep the terminal open while testing so unexpected errors can be copied into
the test report.

### Successful startup indicators

A successful startup has all of these results:

- [ ] The Throttle Meet window opens.
- [ ] A short loading indicator may appear.
- [ ] The event list, an empty-event state, or saved events then appear.
- [ ] The full-screen message `Unable to start Throttle Meet.` does not appear.
- [ ] The terminal does not show an unhandled exception.

Pass: the app reaches the Events screen with no unhandled exception.

Fail: the app remains on loading, closes, shows the full-screen startup error
while online, or reports missing `SUPABASE_URL` or `SUPABASE_KEY`.

## 2. Authentication Tests

### Existing session restoration

1. Launch while online and wait for the Events screen.
2. Record Tester A's anonymous user ID from Supabase Authentication > Users.
3. Close the app normally.
4. Launch it again with the same command and configuration.
5. Recheck the most recent user in Supabase Authentication > Users.

- [ ] The Events screen appears on both launches.
- [ ] The second launch uses the same anonymous user ID.
- [ ] A second anonymous user is not created for the same saved session.

Pass: the same user ID is restored and Events remain accessible.

Fail: every launch creates another user, the restored session cannot reach
Events, or the app displays the full-screen auth failure while online.

### New anonymous session

Use a clean tester installation, separate macOS user, or second test device.

1. Confirm with the coordinator that this environment has no saved session.
2. Launch while online.
3. Open Supabase Authentication > Users.
4. Record the new anonymous user as Tester B.

- [ ] The app automatically reaches Events without a login form.
- [ ] Exactly one new anonymous Supabase user appears.
- [ ] A profile with the same UUID appears in `public.profiles`.

Pass: one anonymous user and matching profile are created automatically.

Fail: login credentials are requested, no user is created, multiple users are
created, or startup remains blocked.

### Authentication failure

Use only a coordinator-approved clean test session.

1. Close the app.
2. Disable Wi-Fi and any wired network connection.
3. Launch in an environment with no saved Supabase session.
4. Observe the startup screen.
5. Reconnect to the network.
6. Select `Retry`.

- [ ] The app shows `Unable to start Throttle Meet.` while authentication cannot
  complete.
- [ ] Events are not created or loaded before a user exists.
- [ ] A `Retry` action is visible.
- [ ] Retry reaches Events after connectivity returns.

Pass: authentication failure blocks startup safely and Retry recovers.

Fail: Events appear without an authenticated user, the app crashes, or Retry
cannot recover after connectivity returns.

### Profile synchronization failure

This test uses an existing authenticated session and saved event snapshot. The
offline steps in the next section create the required conditions.

- [ ] Authentication still reaches Events.
- [ ] A profile warning appears separately from any event refresh warning.
- [ ] Saved events remain usable for read-only viewing.
- [ ] `Retry profile` is available when the profile warning is shown.
- [ ] Reconnecting and retrying clears the profile warning.

Pass: profile failure is non-blocking and does not replace the event error.

Fail: profile failure returns the app to the startup error, removes saved
events, or overwrites the event refresh message.

## 3. Offline Startup Tests

### Create and use a saved snapshot

1. Connect to the network.
2. Launch with an existing authenticated session.
3. Wait for the event list to finish refreshing.
4. Open one event to confirm remote data loaded.
5. Return to the list and close the app normally.
6. Disable Wi-Fi and any wired network connection.
7. Relaunch using the same beta configuration.

- [ ] Cached events appear without waiting for the failed remote refresh.
- [ ] `Showing saved events` appears.
- [ ] An event refresh warning appears without hiding cached events.
- [ ] A profile warning may also appear, but remains separate.
- [ ] Event details can be opened from the saved list.
- [ ] Create, edit, cancel, and RSVP are not reported as successful offline.

Pass: authenticated saved events remain visible and clearly marked as saved.

Fail: startup is blocked by profile sync, cached events disappear, seed events
appear instead, or offline writes are reported as successful.

### Reconnect and recover

1. Leave the app open.
2. Reconnect to the network.
3. Select the event refresh `Retry` action.
4. Select `Retry profile` if the profile warning remains.

- [ ] Remote events replace the saved snapshot.
- [ ] `Showing saved events` disappears.
- [ ] Event and profile warnings clear independently after successful retries.
- [ ] No duplicate events appear.

Pass: the app returns to fresh online state without restarting.

Fail: saved state remains indefinitely, warnings cannot clear, or accepted
events are duplicated or lost.

## 4. Event Creation Tests

Use Tester A and give the event a unique title such as:

```text
Beta Smoke - <tester initials> - <date and time>
```

1. Select `Create Event`.
2. Enter a title, description, host, location, date, and time.
3. Select `Create Event` on the form.
4. Wait for the list refresh.
5. Open the new event.

- [ ] The form requires every text field and a schedule.
- [ ] A success message appears only after creation and refresh succeed.
- [ ] The event appears after refresh.
- [ ] The creator's RSVP is `Going`.
- [ ] The attendee count includes the creator and initially shows `1` when no
  other tester has RSVP'd Going.
- [ ] `Edit event` and `Cancel event` controls appear for Tester A.
- [ ] The SQL ownership query later in this document shows a non-null
  `creator_id` matching Tester A.

Pass: the event, creator ownership, Going RSVP, and count persist together.

Fail: the event is missing, ownership controls are absent, creator RSVP is
empty, attendee count is zero, or the UI reports success while remaining stale.

## 5. RSVP Tests

Use the event created by Tester A. Open it as Tester B in a separate session.
Record the attendee count after every step.

### Interested

1. Tester B selects `Interested`.
2. Wait for refresh, then manually refresh once more.

- [ ] Tester B sees `Interested` selected after both refreshes.
- [ ] The Going attendee count remains `1` because Tester A is Going.

### Going

1. Tester B selects `Going`.
2. Wait for refresh.
3. Tester A refreshes the event.

- [ ] Both sessions show attendee count `2`.
- [ ] Tester B sees `Going`; Tester A still sees Tester A's own status.

### Not Going

1. Tester B selects `Not Going`.
2. Wait for refresh.
3. Tester A refreshes the event.

- [ ] Both sessions show attendee count `1`.
- [ ] Tester B sees `Not Going` after another refresh and app restart.
- [ ] No duplicate RSVP row is created for Tester B.

Pass: each status persists per user and only Going changes attendee count.

Fail: one user's status appears as the other user's status, counts include
Interested or Not Going, refresh reverses the update, or duplicate RSVP rows
appear.

## 6. Ownership Tests

### Owner view

Open Tester A's active event as Tester A.

- [ ] `Edit event` appears.
- [ ] `Cancel event` appears.

### Non-owner view

Open the same event as Tester B.

- [ ] `Edit event` does not appear.
- [ ] `Cancel event` does not appear.
- [ ] RSVP controls remain available while the event is active.

### Ownerless legacy event

Ask the coordinator to identify an event returned by the ownerless-event SQL
query below. Open it in both sessions.

- [ ] `Edit event` does not appear.
- [ ] `Cancel event` does not appear.
- [ ] The legacy event remains readable.

Pass: only the authenticated creator can see owner controls on an active event.

Fail: a non-owner or ownerless event exposes either mutation control, or the
owner cannot manage an active owned event.

## 7. Edit Tests

Use Tester A's active event.

1. Select `Edit event`.
2. Add a recognizable suffix such as `- edited` to the title.
3. Change the description.
4. Change the location.
5. Change the host.
6. Optionally change the date or time.
7. Select `Save Changes`.
8. Wait for refresh and reopen the event.
9. Close and relaunch the app while online.
10. Open the event again.

- [ ] The form is prefilled with the current event values.
- [ ] A success message appears only after save and refresh succeed.
- [ ] Every changed field appears after refresh.
- [ ] The same values remain after restart.
- [ ] The event ID, creator ownership, RSVP statuses, and attendee count are not
  reset by editing.
- [ ] Tester B sees the edited shared fields after refresh.

Pass: all editable fields persist without changing ownership or RSVP data.

Fail: fields revert, a duplicate event appears, RSVP/count data resets, or a
non-owner can edit the event.

## 8. Cancellation Tests

Use Tester A's edited active event.

1. Select `Cancel event`.
2. Confirm that `Cancel this event?` appears.
3. Select `Keep Event` once.
4. Confirm the event remains active and owner controls remain.
5. Select `Cancel event` again.
6. Select `Cancel Event` in the confirmation dialog.
7. Wait for refresh.
8. Refresh again, close the app, relaunch, and reopen the event.

- [ ] No cancellation occurs before confirmation.
- [ ] `Keep Event` dismisses the dialog without changing the event.
- [ ] Confirming cancellation shows `Cancelled event`.
- [ ] RSVP choices are disabled.
- [ ] Edit and Cancel controls disappear.
- [ ] The event remains visible in the list and detail screen.
- [ ] Repeated refresh and restart preserve one stable cancelled state.
- [ ] `cancelled_at` remains populated and unchanged after later reads.

The UI hides Cancel after success, preventing duplicate user actions. The beta
coordinator must also confirm the idempotent RPC assertion passes in
`supabase/tests/verify_event_lifecycle.sql`.

Pass: cancellation requires confirmation, persists as a soft state, disables
mutations, and remains stable across repeated reads.

Fail: cancellation deletes the event, allows RSVP/edit afterward, changes
without confirmation, or reverts after refresh or restart.

## 9. Security Verification in Supabase SQL Editor

These are read-only queries. Run them in the beta project's Supabase SQL Editor
after the UI tests. Replace placeholder values before running. Do not add
`UPDATE`, `INSERT`, or `DELETE` statements.

### Find the smoke-test event and creator

```sql
select
  events.id,
  events.title,
  events.creator_id,
  events.status,
  events.cancelled_at,
  events.created_at,
  events.updated_at
from public.events as events
where events.title = '<EXACT_SMOKE_TEST_TITLE>';
```

Pass:

- Exactly one row is returned.
- `creator_id` is Tester A's Supabase user UUID.
- After cancellation, `status` is `cancelled`.
- After cancellation, `cancelled_at` is non-null.
- `updated_at` is at or after `created_at`.

Fail: no row, duplicate rows, null/wrong creator, active status after confirmed
cancellation, or null `cancelled_at`.

### Confirm ownerless legacy events remain retained

```sql
select
  events.id,
  events.title,
  events.status,
  events.cancelled_at,
  events.created_at
from public.events as events
where events.creator_id is null
order by events.created_at;
```

Pass: known legacy events remain present and have null `creator_id`. Their
presence must not expose owner controls in Flutter.

Fail: legacy rows were unexpectedly deleted or assigned to an unrelated user.

If the beta database intentionally has no legacy rows, record `Not applicable`
instead of creating one solely for this smoke test.

### Confirm RSVP rows and authenticated Going count

Replace `<SMOKE_TEST_EVENT_ID>` with the ID from the first query.

```sql
select
  event_rsvps.event_id,
  event_rsvps.user_id,
  event_rsvps.participant_id,
  event_rsvps.status,
  event_rsvps.created_at,
  event_rsvps.updated_at
from public.event_rsvps as event_rsvps
where event_rsvps.event_id = '<SMOKE_TEST_EVENT_ID>'
order by event_rsvps.created_at;
```

Pass:

- Tester A and Tester B each have at most one row with their `user_id`.
- Authenticated rows have non-null `user_id`.
- The final saved statuses match the UI.

Fail: duplicate rows exist for one user/event pair, authenticated rows have no
`user_id`, or stored status differs from the UI after refresh.

Run the aggregate query:

```sql
select
  events.id,
  events.title,
  count(event_rsvps.id) filter (
    where event_rsvps.user_id is not null
      and event_rsvps.status = 'going'
  ) as authenticated_going_count,
  count(event_rsvps.id) filter (
    where event_rsvps.user_id is null
      and event_rsvps.status = 'going'
  ) as legacy_going_rows_excluded_from_v2,
  count(event_rsvps.id) filter (
    where event_rsvps.user_id is not null
  ) as authenticated_rsvp_rows
from public.events as events
left join public.event_rsvps as event_rsvps
  on event_rsvps.event_id = events.id
where events.id = '<SMOKE_TEST_EVENT_ID>'
group by events.id, events.title;
```

Pass:

- `authenticated_going_count` matches the attendee count last shown in the
  app.
- Only rows with non-null `user_id` contribute to that count.
- Legacy participant-only Going rows, if any, are shown separately and do not
  inflate the v2 count.

Fail: the displayed count differs from `authenticated_going_count` after a
successful refresh, or participant-only rows affect the authenticated count.

## 10. Expected Results Summary

- [ ] Environment: beta configuration launches the macOS app successfully.
- [ ] Authentication: existing sessions restore and clean installs create one
  anonymous user.
- [ ] Auth failure: startup blocks safely until an authenticated user exists.
- [ ] Profile sync: failure is non-blocking and separately reported.
- [ ] Offline startup: saved events appear with `Showing saved events`.
- [ ] Recovery: reconnecting clears saved/error state after successful retries.
- [ ] Creation: creator becomes Going and attendee count starts correctly.
- [ ] RSVP: per-user status and Going counts survive refresh and restart.
- [ ] Ownership: only owners of active events see Edit and Cancel.
- [ ] Editing: shared fields persist without altering ownership or RSVP data.
- [ ] Cancellation: confirmation, soft cancellation, disabled RSVP, and
  persistence all work.
- [ ] Security SQL: creator, lifecycle, uniqueness, and authenticated counts
  match the UI.

Any unchecked item is a failed or incomplete smoke test. Record the exact step,
screenshots without credentials, terminal output, user IDs, event ID, expected
result, and actual result in the beta issue.

## 11. Beta Exit Criteria

Do not invite external controlled-beta testers until all applicable items pass:

- [ ] The entire smoke test passes on at least one supported macOS device.
- [ ] Authentication restoration passes after a complete app restart.
- [ ] A clean session can create exactly one anonymous user and profile.
- [ ] Offline startup shows an authenticated user's saved snapshot.
- [ ] Online recovery replaces the snapshot with fresh events.
- [ ] Two independent users complete the full RSVP count sequence.
- [ ] Event creation atomically produces creator ownership and Going RSVP.
- [ ] Owner edit persists every supported field across restart.
- [ ] Non-owner and ownerless events expose no owner controls.
- [ ] Cancellation remains visible, confirmed, persistent, and read-only.
- [ ] All read-only SQL security checks pass.
- [ ] `verify_event_lifecycle.sql` passes in the beta database environment.
- [ ] `verify_security_cutoff.sql` passes in the beta database environment.
- [ ] `flutter analyze` passes for the release commit.
- [ ] `flutter test` passes for the release commit.
- [ ] No unresolved critical or high-severity security or data-integrity bug is
  open.
- [ ] The beta coordinator has documented rollback ownership and contact steps.

Final result:

- [ ] PASS — approved to invite the controlled tester group.
- [ ] FAIL — invitation remains blocked until failed items are corrected and
  retested.
