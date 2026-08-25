# Plan 02 outcome — Supabase client and the auth slice

**Completed:** 2026-08-23 · **Branch:** `supabase-auth-slice` · 17 commits
**Project:** `arxrtodtnrmhwbecwyxm` · 20 migrations applied · 1 Edge Function deployed

All 10 tasks complete. `flutter analyze` clean, **100/100 Dart tests passing**.

Login, sign-up, session restore, forced password change and staff provisioning
now run against real Postgres. Appointments, prescriptions, health metrics,
pharmacy and chat still run on the in-memory mock — deliberately, and deferred
to Plan 03 onward.

---

## What this slice actually changed

| Area | Before | After |
|------|--------|-------|
| Auth | In-memory `CredentialsStore`, salted SHA-256, session-lifetime | Supabase Auth, real JWTs, persisted sessions |
| Profile lookups | 16 synchronous call sites reading a repository inside `build()` | `FutureProvider.family`, no widget reads a network value synchronously |
| Session restore | User id in Hive | Supabase's own persisted session; Hive only in mock mode |
| Staff creation | Client-side | Edge Function holding the service-role key, doctor-gated server-side |
| Doctor assignment | Client-written | `assign_default_doctor()`, clinic-scoped, least-loaded doctor |
| Registration | Three sequential client writes | One atomic `register_patient()` transaction |
| Platform split | Staff blocked on mobile only | Symmetric: staff web-only, patients mobile-only |
| Backend switch | `Env.isMockMode = true` constant | `--dart-define=MYPULSE_MOCK=true`, defaults to real |

---

## Defects caught before they reached the demo

Seven real defects, six of them in this plan's own code or SQL.

| # | Defect | Severity | Found by |
|---|--------|----------|----------|
| 1 | `assign_default_doctor` was role-gated but not clinic-scoped — any doctor at any clinic could rewrite any patient's care team | Important | Task 1 review |
| 2 | A refused login left a live session: `signInWithPassword` establishes a session *before* the profile check, and the no-profile path never signed out | Important | Task 6 review |
| 3 | `setAccountActive` could never work — Plan 01 correctly revoked `is_active` from clients, and Plan 02 forgot | Important | Task 6 review |
| 4 | **Sign-up was dead on arrival.** It inserted into `profiles`, which has no INSERT policy in any migration. Every registration would have failed with 42501 | **Critical** | Task 7 review |
| 5 | Partial sign-up stranded an auth user with no `patient_profiles` row and no way to re-register | Important | Task 7 review |
| 6 | `invoke` *throws* on non-2xx rather than returning, so the entire Edge Function error branch was unreachable and every server error read "Something went wrong" | Important | Task 8 review |
| 7 | **`must_change_password` could never be cleared** — same forgotten hardening as #3, in the adjacent method. Every staff account the Edge Function created would be trapped on the password screen forever | Important | Task 8 review |

Two more surfaced only from running the real app:

8. **Every seeded demo account was unable to log in.** The seed inserted
   `auth.users` rows by hand, leaving `confirmation_token`, `recovery_token`,
   `email_change` and `email_change_token_new` NULL. GoTrue scans those into
   non-nullable Go strings, so sign-in returned a 500 *before* checking the
   password. The accounts looked perfect in SQL — the bcrypt hash verified — and
   simply could not authenticate. Plan 01's seed test asserted the hash and never
   attempted a login.
9. **The quick demo buttons pointed at mock accounts** (`sarah@example.com`,
   `fatima@mypulse360.clinic`) that do not exist in Supabase. Since removed
   entirely.

**Defects #3, #7 and #8 are the same lesson three times:** Plan 01 hardened the
database correctly, and Plan 02 repeatedly forgot that it had. Column grants and
hand-written `auth.users` rows both fail at runtime with errors that point
somewhere else.

### Defective tests of the plan's own, caught by implementers

Each was caught by an implementer refusing to quietly make a red assertion green:

- An assertion searching for `'not your clinic'` when the function raises
  `'not at your clinic'` — `position()` returned 0, so it passed regardless of
  what it claimed to check.
- Two isolation assertions inherited from Plan 01 that passed because the other
  patient owned no rows.
- A `set_account_active` test that proved only that the migration applied.

---

## Verified

Against the live project:

- All three roles return `200` with an access token: patient, doctor, pharmacist.
- `profiles` still has **no INSERT policy** — registration is server-side only,
  so a client can never insert its own profile row and name its own role.
- `assigned_doctor_id`, `is_active` and `must_change_password` are **not
  client-writable**; each has a definer RPC as its only write path.
- The Edge Function establishes caller identity from the caller's JWT and the
  publishable key, instantiates the service client only *after* the doctor check,
  and ignores the body's `clinicId`.
- No service-role key or JWT is committed anywhere.

By test:

- 100/100 Dart tests, including a widget test that guards the splash race. Its
  non-vacuity was proven by reverting the fix and watching it fail with
  `Expected: '/splash', Actual: '/login'`.

---

## Demo credentials

| Role | Email | Password | Platform |
|------|-------|----------|----------|
| Patient | `aisha.rahman@mypulse360.test` | `Patient123!` | **Mobile only** |
| Patient | `daniel.okafor@mypulse360.test` | `Patient123!` | **Mobile only** |
| Doctor | `ahmed.rashid@mypulse360.test` | `Doctor123!` | **Web only** |
| Doctor | `lina.fernandez@mypulse360.test` | `Doctor123!` | **Web only** |
| Pharmacist | `nur.hakim@mypulse360.test` | `Pharma123!` | **Web only** |

The platform split is enforced in both datasources and refuses the wrong pairing
with a specific message. **For a demo this means the patient app must be shown on
a phone or emulator, and staff on the web build** — one browser window cannot
show all three roles.

To demo entirely offline, `--dart-define=MYPULSE_MOCK=true` runs the whole app on
the in-memory mock with no network.

---

## Outstanding follow-ups

### Before the next slice

1. **`MockAuthDataSource` diverges from the real backend.** Its
   `setAccountActive` allows self-deactivation and has no clinic scope, while the
   RPC refuses both. The 100 tests run against the mock, so they are no evidence
   for the real guards.
2. **`auth_role()` ignores `is_active`.** Deactivation is checked only at login,
   so a staff member deactivated mid-session keeps a working JWT until it
   expires and can still call both staff-management paths.
3. **`authenticated` holds INSERT on every `profiles` column**, including `role`.
   Inert today because no INSERT policy exists — but if one is ever added, `role`
   becomes client-settable. Registration is definer-only now, so INSERT should be
   revoked outright.
4. **The splash poll has no timeout.** If the profile fetch hangs, the user is
   parked on the brand screen indefinitely with no error and no escape.

### Carried from Plan 01, still open

5. Migration filenames do not match applied versions; run
   `supabase migration repair --status applied <version>` before any `db push`.
6. Deleting a user is still impossible — eight FKs point at `profiles` with
   `NO ACTION`. `is_active` implies soft-delete; that should be documented.

---

## Design decisions worth remembering

**RLS chooses rows; column grants choose columns; definer RPCs are the write
path for authority columns.** `role`, `clinic_id`, `is_active`,
`must_change_password` and `assigned_doctor_id` are all deliberately not
client-writable. Every one of them has an RPC, and three of the defects above
were forgetting that.

**`profiles` has no INSERT policy on purpose.** Registration goes through
`register_patient()` so a client can never insert a row naming its own role. The
test suite asserts the absence of that policy, so a future "just add an INSERT
policy" workaround is caught.

**Never hand-write `auth.users`.** GoTrue reads several token columns into
non-nullable strings. A row that looks correct in every SQL check can be
completely unable to authenticate.
