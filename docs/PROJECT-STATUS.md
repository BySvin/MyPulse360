# MyPulse360 — project status

**As of 2026-08-25.** A factual account of what is built, what is not, and how
it was verified. Written to be quoted from in a report.

---

## What the system is

A clinic platform serving three roles from one Flutter codebase: patients on
mobile, doctors and pharmacists on a web dashboard. The backend is Supabase
(PostgreSQL 17) with row-level security, server-side functions, and one Edge
Function.

---

## Delivered

### Database — complete

| | |
|---|---|
| Tables | 27, every one with row-level security enabled |
| Enum types | 14, mirroring the Dart domain enums |
| Server-side functions | 17, all `SECURITY DEFINER` with a pinned `search_path` |
| Edge Functions | 1 (`create-staff-account`) |
| Migrations | 24 |
| SQL test files | 22 |

**The authorization model.** Row-level security decides *which rows* a caller
sees; column-level grants decide *which columns* they may write; and the columns
that carry authority — `role`, `clinic_id`, `is_active`, `must_change_password`,
`assigned_doctor_id` — are writable by **no client at all**. Each has exactly one
server-side function as its write path.

`profiles` deliberately has **no INSERT policy**, and a committed test asserts
its absence, so registration cannot be moved client-side by accident. A client
that could insert its own profile row could name its own role.

**Integrity enforced by the database, not the app:**

- A partial unique index makes double-booking a time slot impossible.
- Dispensing consumes stock earliest-expiry-first under row locks, and fails
  loudly rather than handing over less medication than requested.
- Approving leave cancels the appointments it collides with in the same
  transaction.
- Queue position is derived, never stored, so it cannot go stale on a cancel.

### Application — auth, appointments and patient profile complete

Authentication, sign-up, session restore, forced password change, patient and
staff profiles, staff provisioning and account activation all run against
Postgres — and as of the appointments slice, so do **appointment booking,
rescheduling, cancellation, slot availability and the patient health profile**.

Two things are genuinely live over Postgres realtime: the patient's next
upcoming appointment and the doctor's queue for today. Reads are `FutureProvider`s
and every screen renders its `AsyncValue` through one shared widget, so a value
that has not loaded is never drawn as though it were an answer.

`flutter analyze` is clean and **123 Dart tests pass**.

### Not yet migrated

Prescriptions, health metrics, pharmacy inventory, staff scheduling and the
chatbot still run against an in-memory mock. This is a sequenced migration, not
an oversight: `docs/superpowers/specs/2026-08-22-supabase-backend-design.md`
§9 defines nine slices, four of which are now done. Plan 04 takes prescriptions
and consultations next.

The mock is retained deliberately as the test double and as an offline demo
mode, not as dead code.

---

## How it was verified

Verification was treated as part of the work rather than a final step.

**Automated.** 123 Dart tests; 22 SQL test files including a cross-tenant
isolation suite that signs in as one patient and asserts they cannot read
another's records — with a counter-check proving the other patient's rows exist,
so the assertion cannot pass merely because a table is empty.

**Against the live project.** Every role's sign-in, the Edge Function's refusal
of a non-doctor (`403`), successful provisioning into the caller's own clinic,
the forced password-change gate clearing, account deactivation, and the refusal
of a doctor attempting to deactivate themselves.

**By review.** Each unit of work was reviewed against its specification before
being accepted, then the whole branch was reviewed as a system.

---

## Defects found and fixed before release

Twenty-four across the project. The eleven that mattered most:

| Defect | Why it mattered |
|---|---|
| A patient could rewrite the medications on a prescription their doctor issued, while the record still read as doctor-authored | Prescription forgery the database permitted |
| A patient could set their own role to `doctor` and read every profile in their clinic | Complete privilege escalation |
| `dispense_fefo` could silently dispense less medication than requested and report success | Wrong quantity, no error |
| Sign-up inserted into a table with no INSERT policy | Registration could never have worked |
| Staff accounts were permanently trapped on the password-change screen | The flag could not be cleared by any client |
| Every seeded account was unable to log in | Hand-written `auth.users` rows left columns NULL that GoTrue reads as non-nullable |
| A patient could reach the staff web dashboard | Layout never designed for them |
| Any doctor at any clinic could reassign any patient's care team | Cross-tenant write |
| The appointments datasource was correct but wired to nothing | The whole slice was dead code; the plan put the wiring in an earlier task that ran before the datasource existed |
| Deleting an account reported success without deleting anything | A table-level DELETE grant with no DELETE policy matches zero rows and returns success under RLS |
| The whole clinic ran in the wrong timezone | Opening hours of 09:00-17:00 were read as UTC, so the clinic was open 5pm-1am local. Self-consistent end to end, which is exactly why nothing contradicted it |

**Nine of the twenty-four were only visible where two individually-correct
changes met** —
a datasource nothing constructed, a wiring change that made three unguarded call
sites live, a deletion that would have broken sign-up in the offline demo. That
is why each unit is reviewed against its specification *and* the branch is then
reviewed again as a whole; neither step alone finds them.

**Three defective tests were also caught** — each by refusing to make a red
assertion green without understanding it. One could never pass at all
(it matched a value PostgreSQL never emits); two passed for the wrong reason
(they asserted a patient saw zero of another's rows, when that patient owned no
rows at all).

---

## Known limitations

Stated plainly rather than hidden.

1. **Five features remain on the mock** — prescriptions, health metrics,
   pharmacy inventory, staff scheduling and the chatbot.
2. **Clinic timezone is a single value, not per-doctor.** `clinics.timezone`
   (default `Asia/Kuala_Lumpur`) is what opening hours are read in. A clinic
   spanning multiple zones, or a doctor working remotely from another, is not
   modelled. The column is server-managed — clients hold `SELECT` on `clinics`
   and nothing else.
3. **A deactivated staff member keeps a valid session until their token expires**
   (one hour). `is_active` is checked at sign-in, not on every request.
4. **No account erasure.** Eight foreign keys reference `profiles` with
   `NO ACTION`, so a user with any history cannot be deleted. `is_active` is the
   intended soft-delete; a GDPR erasure path is not implemented.
5. **The two routing fixes in the auth slice rest on code review**, not tests.
6. **Migration filenames do not match their applied versions.** Run
   `supabase migration repair --status applied <version>` before any `db push`.
7. **Self-service sign-up needs email confirmation disabled** in the project's
   auth settings; see `docs/DEMO.md`.

---

## Where to look in the repository

| Path | What it holds |
|---|---|
| `supabase/migrations/` | 24 migrations, in order |
| `supabase/tests/` | SQL assertions, including the isolation suite |
| `supabase/functions/create-staff-account/` | The one server-side function |
| `lib/features/*/data/datasources/` | Paired mock and Supabase implementations |
| `docs/superpowers/specs/` | The design the whole migration argues from |
| `docs/superpowers/plans/` | Per-slice plans and their outcome records |
| `design-system/` | Colour, typography and spacing tokens with contrast ratios |

The outcome documents are worth reading alongside the code: each records what
was built, what was found wrong, and which decisions were deliberate.
