# Plan 01 outcome — Supabase database foundation

**Completed:** 2026-08-23 · **Branch:** `supabase-backend` · 30 commits
**Project:** `arxrtodtnrmhwbecwyxm` · 15 migrations applied · 27 tables · 16 test files

All 11 tasks complete. Whole-branch review verdict: **ready with follow-ups**.
No Dart application code was migrated — that is Plan 02 onward. `flutter analyze`
clean, 91/91 Dart tests passing throughout.

---

## Defects caught before they reached production use

Eight real defects were found by review rather than by users. Six were in this
plan's own SQL.

| # | Defect | Severity | Found by |
|---|--------|----------|----------|
| 1 | `language sql` bodies are validated at `CREATE FUNCTION`, not call time — would have rolled back migration 1 entirely, enums included | Blocker | Task 1 implementer |
| 2 | Any patient could `update profiles set role = 'doctor'` and read every profile in their clinic | Critical | Task 2 review |
| 3 | That fix closed UPDATE; the hole moved to INSERT rather than closing | Critical | Task 2 re-review |
| 4 | `dispense_fefo` could silently dispense **less medication than requested** under concurrency and report success | Important | Task 7 review |
| 5 | `staff_unavailability_read` was `using (true)` — any patient could read every staff member's leave reasons | Important | Task 8 review |
| 6 | `decide_leave` compared `scheduled_at::date`, TimeZone-dependent, in a file that avoided that exact bug two functions earlier | Important | Task 8 review |
| 7 | **A patient could rewrite the medications on a prescription their doctor issued**, while the parent row still read as doctor-authored. Prescription forgery the database permitted | **Critical** | Whole-branch review |
| 8 | `decide_leave` had no clinic scoping — any doctor could approve any staff member's leave anywhere and cancel their appointments | Important | Whole-branch review |

Three defective **tests** of the controller's own were also caught, each by the
implementer refusing to quietly make a red assertion go green:

- An assertion filtering `parameter_mode = 'TABLE'`, a value Postgres never
  emits — it would have reported FAIL forever regardless of correctness.
- Two isolation assertions that passed because the other patient owned no rows,
  not because RLS denied them — they would have passed with RLS switched off.
- An assertion for defect 7 that used `select count(*)`, testing *readability*
  when the vulnerability was a *write*. Replaced with a real UPDATE attempt that
  demonstrated a patient rewriting a medication to `'Forged medication'`.

One reviewer finding was **rejected as a false positive** after direct
verification: a claim that no unique constraint backed `book_appointment`'s
`23505`. The guard is `appointments_no_double_booking`, created via
`CREATE UNIQUE INDEX`, which does not appear in `pg_constraint` — the reviewer
queried the wrong catalog. Confirmed `indisunique = true`, `indpred not null`.

---

## Outstanding follow-ups

Surfaced deliberately rather than fixed, so they are visible decisions.

### From the final review — small, worth doing before Plan 02

1. **`revoke delete`** on `consultations`, `prescriptions`, `health_metrics`,
   `inventory_items`, `inventory_batches`. Their DELETE *policies* were removed
   but the table *grants* were not, recreating the grant/policy disagreement that
   an earlier finding existed to eliminate. Not exploitable — RLS denies with no
   permissive DELETE policy — but inconsistent.
2. **No positive control** on the prescription fix: nothing asserts a patient can
   *still* edit items on a prescription they scanned themselves. Over-tightening
   would also read PASS. The capability was verified present in `pg_policies`,
   but not by a test.
3. **`decide_leave` leaks a status oracle**: it raises "not found" / "already
   decided" before its clinic check, so a doctor holding a request UUID can
   distinguish states across clinics. Move the clinic check above the status
   checks.

### Structural, for Plan 02

4. **Migration filenames do not match applied versions.** Files are `0001_…`;
   applied versions are timestamps. `supabase migration list` will show all 14 as
   un-applied and `db push` would try to re-run them — and since the files use
   bare `create table`, that run fails partway. Rename to applied timestamps or
   run `supabase migration repair --status applied <version>` for each.
5. **No `supabase/config.toml`**, so `supabase start` / `db reset` cannot run.
6. **Every per-task test asserts existence, not behaviour.** The isolation and
   RPC suites are the only behavioural coverage. Once Dart is wired against this
   schema, a silent policy regression becomes a breach with no alarm.
7. **Deleting a user is impossible.** `profiles.id` cascades from `auth.users`,
   but eight FKs point at `profiles` with `NO ACTION`, so any user with one
   appointment cannot be deleted. `is_active` implies soft-delete is intended —
   decide and document it, and note there is no erasure story for GDPR.
8. **`assigned_doctor_id` can no longer be set from a client** (correctly).
   Sign-up must assign the clinic's default doctor server-side via a definer RPC
   or trigger. Dart's `PatientProfile.assignedDoctorId` is non-nullable and needs
   reconciling.

### Accepted as-is, with reasons

- `doctor_availability_read` is `using (true)` — working hours are not PII and
  the booking flow needs them.
- `inventory_batches` stays pharmacist-writable — receiving stock and stock-take
  corrections need it. The spec's §6 write-discipline list overstates the
  guarantee; migration `0015` records the correction.
- `queue_position` has no timestamp tiebreaker — the double-booking index makes
  the tie unreachable.
- `available_slots` exposes `is_doctor_on_leave` (the boolean, not the reason) to
  any authenticated caller. Patients need it to book.

---

## Design decisions worth remembering

**RLS chooses rows; column grants choose columns.** Authorization needs both.
Row-level policies alone let a patient rewrite the very column
(`profiles.role`) that the policies consult to decide authorization.

**Ordering, not suppression.** Two forward-reference failures were fixed by
moving function creation after its dependencies, never by
`check_function_bodies = off` or stub tables.

**`SECURITY DEFINER` functions are the only sanctioned write path** for
`appointments`, `leave_requests`, `attendance_records` and `dispense_records`.
Direct client writes are revoked, so the leave, collision and stock checks are
enforcement rather than advice.

**Everything is UTC-anchored.** `p_date + start_time` is a timestamp *without*
zone; left implicit its cast depends on the connection's TimeZone, so two
clients in different zones compute different slots.
