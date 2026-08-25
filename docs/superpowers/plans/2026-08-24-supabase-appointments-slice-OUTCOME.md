# Outcome — Supabase appointments slice (Plan 03)

**Branch:** `supabase-appointments-slice`
**Completed:** 2026-08-25

A record of what was built, what was found wrong, and which decisions were
deliberate. Written to be read alongside the diff.

---

## What this slice did

Appointments and the patient profile now read and write **PostgreSQL** instead
of the in-memory mock. Reads are `FutureProvider`s, the two genuinely live
things — the patient's next appointment and the doctor's queue for today — are
`StreamProvider`s on Postgres realtime, and every screen renders its `AsyncValue`
through one shared widget so "loading" is never silently rendered as an answer.

The mock is **not** deleted. It remains the test double and the
`--dart-define=MYPULSE_MOCK=true` offline demo.

## Tasks

| # | What | Commit |
|---|---|---|
| 1 | `month_availability` RPC — one call per month, not 31 | earlier |
| 2 | Row mapping (`db_rows.dart`, `db_enums.dart`) | earlier |
| 3+4 | Async interfaces; consumers converted to `AsyncValue` | `59189ef..de1df5b` |
| 5 | `SupabaseAppointmentsDataSource` reads + both realtime streams + `0023` | `5710cf3` |
| 7 | `SupabasePatientDataSource` | `094773f` |
| 6 | Booking, reschedule, status writes, and the wiring | `c321706` + fix |
| 8 | Verification (this document) | — |

Task 7 ran **before** Task 6 deliberately: booking needs
`profile.assignedDoctorId` to be a real doctor UUID, and until the patient
feature moved to Postgres it was a mock id.

---

## Verification

### Against the live project

Run as the seeded patient over REST with the publishable key, so RLS and the
RPCs are exercised exactly as the client exercises them. Recorded as observed.

| Check | Result |
|---|---|
| `available_slots` for a weekday | **16 slots**, 09:00–16:30 |
| Book a free slot | `200`, appointment created |
| **Book the same slot again** | **`409` / `23505` / "slot unavailable"** |
| `mapPostgrestError('23505')` | → "That time slot was just taken. Please pick another." |
| Slot while booked → after cancel | `is_booked` `true` → `false` |
| Cancel as the patient | `200`, status `cancelled` |

Plan 01's RPC behaviour suite (`0016_rpc_behaviour_test.sql`) re-run block by
block against the live project: **5/5 PASS**, including *approved leave cancels
the appointments it collides with* and both `dispense_fefo` guarantees.

**Realtime was verified end to end, not assumed.** A throwaway Dart harness
subscribed to the exact stream `watchTodaysQueue` builds — signed in as the
doctor, same `.stream(primaryKey: ['id']).eq('doctor_id', ...)` — then booked an
appointment as the patient from a second client:

```
emission 1: 1 rows          <- initial snapshot
booked 6f664675... at 2026-08-28 15:30Z
emission 2: 2 rows          <- arrived over the socket, no refetch
RESULT: PASS
new row present in latest emission: true
```

This is the single thing in the slice that fails *silently* when wrong: without
migration `0023` the stream emits its first snapshot and then never updates,
which is indistinguishable from a quiet clinic. The harness was deleted and the
probe row removed.

`supabase_realtime` contained **no tables at all** before this slice. Migration
`0023` adds `appointments`; verified `[]` before, `appointments` after. Without
it both streams emit their first snapshot and then silently never update —
which looks exactly like working code.

### Automated

`flutter analyze` clean. **116 Dart tests pass** (114 before this slice's final
task, plus the two request-count assertions below). SQL suites unchanged and
passing.

### Verified by running the real code

Beyond the SQL, the **actual datasource classes** were driven against the live
project — sign-in, profile, goals, slot fetch, book, duplicate-book, reschedule,
cancel, the doctor's realtime queue, and a cross-patient read. This exercises the
Dart mapping, timezone handling and error translation, not just the database:

```
first slot: raw=2026-08-26T01:00:00.000Z shown=9:00 AM
duplicate refused: That time slot was just taken. Please pick another.
queue today: 9:00 AM completed / 10:00 AM completed / 1:00 PM confirmed / 3:00 PM scheduled
cross-patient read blocked
```

**This found a defect two rounds of review had passed.** `getForPatient` still
returned newest-first after the "fix" for it, because postgrest-dart's `order()`
defaults to **descending** — the opposite of SQL and of postgrest-js. Dropping
`ascending: false` therefore changed nothing. The code read correctly, which is
why review missed it twice; only running it showed the wrong order. Now set
explicitly, with a test asserting the emitted query
(`order=scheduled_at.asc`).

The lesson is narrow and worth keeping: **a review can only check that code says
what it means, not that a library means what it says.**

### Not verified by me — checked by the developer instead

#### The browser-driven UI

The developer ran the Windows desktop build by hand after the timezone fix and
confirmed the app behaves correctly end to end. That is their observation, not
mine — recorded as such.

**I could not drive the UI in this environment.** The
Browser pane does not composite frames, and Flutter web paints to a canvas via
`requestAnimationFrame` — with no compositing there is no `flt-scene`, no
`<canvas>`, and an empty semantics tree. I confirmed all of that in the DOM. The
app loads correctly (assets 200, Hive opens) but cannot paint, so it cannot be
driven. No external Chrome was connected either.

What that does and does not cost:

- The behaviour behind rows 2, 3, 4, 7 and 8 is verified **against the live
  database**, which is stronger evidence than a screenshot.
- Row 1 — "one `month_availability` request, not 31" — is the entire
  justification for Task 1. Rather than leave it unproven, it is now a
  **committed widget test** with a counting fake datasource
  (`test/features/appointments/month_calendar_request_count_test.dart`). It
  asserts one call per rendered month, one more per page-forward, and **zero**
  per-day slot calls. The assertion was confirmed able to fail by flipping the
  expected count to 31 and watching it go red. This is better than the plan's
  original method: a number read off a network panel once proves nothing after
  tonight; a test proves it on every future run.
- Row 5 — "doctor's queue shows the booking without a manual refresh" — is
  verified by the realtime harness above, minus the widget rebuild itself, which
  is ordinary `StreamProvider` behaviour.
- A minified `Uncaught dartException` appears in the console on load. It cannot
  be attributed while the app cannot render, and it is **not** evidence of a
  crash — no Supabase request is expected before sign-in, and `localStorage` is
  empty, so there is no session to restore. Recorded as **unresolved**, not
  dismissed.

---

## Defects found and fixed

Ten in this slice — seven found by per-task review, three more by the
whole-branch review that followed. The pattern worth noting: **six existed only
*between* two individually-correct changes**, which is why each task is reviewed
against its brief *and* the branch is then reviewed again as a whole. Neither
step alone finds them.

| # | Defect | Why it mattered |
|---|---|---|
| 1 | The appointments repository was **never wired to Supabase** | Everything Task 5 built was dead code. The plan put the wiring in Task 4, which ran *before* the Supabase datasource existed; Task 5's brief did not own the file. It fell through the seam. |
| 2 | Wiring made three write call sites live that had **no error handling** | Reschedule spun its button forever with no message; Cancel failed silently. Only `_book` had been given a `catch`. |
| 3 | `watchNextUpcoming` sampled "now" **once**, when the stream was built | An appointment that had already started kept being announced as "next upcoming" for the life of the session. Its sibling did it correctly — the asymmetry is what exposed it. |
| 4 | `getForPatient` sorted **newest-first** | The mock and the list page both assume oldest-first, so both tabs rendered backwards. Came verbatim from the plan. |
| 5 | Deleting `_ensureLocalPatientProfile` would have **broken sign-up in mock mode** | It is the only code that creates a profile row, and the mock's `updateProfile` throws without one. The plan said to delete it. |
| 6 | `deleteAccount` would have **silently succeeded** | `patient_profiles` has a table-level DELETE *grant* but no DELETE *policy*, so under RLS a delete matches zero rows and returns success — telling a patient their record was erased when nothing happened. |
| 7 | `createInitialProfile` could not honour its own signature | No client may write `assigned_doctor_id`; `assign_default_doctor()` is the single write path. Returning a profile with an empty doctor id would have fed straight into booking. |
| 8 | The router force-redirected an onboarded patient into onboarding on a **failed** profile fetch | It guarded `isLoading` but not `hasError`, so a dropped connection made `onboarded` compute to `false` — from every route, for every patient. Only reachable once this slice made `getProfile` a network call. |
| 9 | The patient's Home tab said "No goals yet" **while goals were loading** | Every patient with goals was told they had none on every cold load; health insights vanished in the same window. Seventh instance of this bug class on the branch — it survived because the file was outside the earlier fix round's scope even though this slice made its providers async. |
| 10 | Approving leave could cancel **some** colliding appointments and report a generic failure | The leave stays filed and some patients still expect to be seen; the doctor could not tell which. Now says so explicitly, with no silent rollback. |

Defects 1, 4 and 5 were **defects in the plan itself**, found by implementers
and reviewers pushing back rather than complying. Defect 6 was a correction to
the controller's own pre-flight finding, and the corrected version is sharper
than the original.

Defect 8 deserves a specific note: the Task 7 implementer **flagged that exact
shape in its report** and it was deferred rather than judged. The whole-branch
review then found it independently. An escalation that is acknowledged and then
dropped is worse than one never made, and it is recorded here rather than
quietly folded into the count.

Every test added for defects 8, 9 and 10 was **proven able to fail** by
reintroducing the defect and watching it go red — reverting the router guard
yields `Expected: '/login', Actual: '/onboarding/welcome'`. This project has
shipped six assertions that could never fail; the bar is now that a new test
must be seen red before it is kept.

---

## Deliberate decisions

- **`_ensureLocalPatientProfile` was kept, not deleted** (the plan said delete).
  It is now guarded by `if (!Env.isMockMode) return;` and renamed
  `_ensureMockPatientProfile`. In Supabase mode it is genuinely redundant —
  `register_patient()` inserts the profile and assigns a doctor in one
  transaction. In mock mode it is the only thing that creates the row.
  **The plan's "Done criteria" claims this was deleted; it was not, and that
  criterion is superseded.**
- **`appointmentsRevisionProvider` was kept.** Scheduling and pharmacist
  providers still watch it and are still mock-backed. It goes in the cutover
  slice.
- **The wiring shipped in the same commit as the writes**, never before, so the
  app was never in a state where booking crashed rather than simply being absent.
- **`createInitialProfile` throws on Supabase** naming `register_patient` as the
  real path, rather than doing a two-round-trip insert outside that RPC's
  transaction.

---

## Known limitations

Stated plainly rather than hidden.

1. ~~Slots are generated in UTC.~~ **Fixed after this slice** by migration
   `0024_clinic_timezone.sql`. `clinics.timezone` (default `Asia/Kuala_Lumpur`)
   now anchors slot generation, both write RPCs resolve the calendar day in
   clinic time, and `DateFormatters` renders every timestamp locally. What
   remains is narrower: one timezone per clinic, so a clinic spanning zones is
   not modelled.
2. **The browser matrix rows are unverified** — see above.
3. **The two realtime streams filter in Dart on each emission.** Supabase
   realtime supports `.eq` on the stream builder but not arbitrary predicates,
   so the date and status filters run client-side. Correct, but every row for
   that doctor reaches the client.
4. Everything in `docs/PROJECT-STATUS.md` §"Known limitations" that this slice
   did not change still applies.

---

## Still on the mock

Prescriptions, health metrics, pharmacy inventory, staff scheduling and the
chatbot. Plan 04 takes prescriptions and consultations next; the cutover slice
deletes `appointmentsRevisionProvider` and flips the remaining `Env.isMockMode`
consumers.
