# MyPulse360 — demo guide

Everything below was verified against the live Supabase project on 2026-08-24.

---

## Before you start — one dashboard setting

**Self-service sign-up will fail unless you turn off email confirmation.**

The hosted project currently requires a new user to confirm their email before
they get a session. The app's sign-up needs that session immediately, to call
`register_patient()` — so without this change, registering ends in an error.

Supabase dashboard → **Authentication → Sign In / Providers → Email** →
turn **off** "Confirm email" → Save.

(The seeded demo accounts are unaffected — they were created already confirmed.
This only matters if you want to demo *registering a new patient*.)

If you would rather not change it, skip the sign-up step and demo with the
seeded accounts, which work as-is.

---

## Accounts

| Role | Email | Password | Where it works |
|------|-------|----------|----------------|
| Patient | `aisha.rahman@mypulse360.test` | `Patient123!` | **Mobile only** |
| Patient | `daniel.okafor@mypulse360.test` | `Patient123!` | **Mobile only** |
| Doctor | `ahmed.rashid@mypulse360.test` | `Doctor123!` | **Web only** |
| Doctor | `lina.fernandez@mypulse360.test` | `Doctor123!` | **Web only** |
| Pharmacist | `nur.hakim@mypulse360.test` | `Pharma123!` | **Web only** |

The platform split is deliberate and enforced server-side in the datasource:
staff sign in on the web dashboard, patients in the mobile app. Signing in on
the wrong one gives a clear message rather than failing.

**One window cannot show all three roles.** Plan for two: a phone or emulator
for the patient, a browser for staff.

---

## Running it

**Staff (web):**

```bash
flutter run -d chrome
```

**Patient (mobile):**

```bash
flutter run
```

**Fully offline fallback** — if the venue's wifi is unreliable, this runs the
entire app against the in-memory mock with no network at all, all three roles in
one window:

```bash
flutter run --dart-define=MYPULSE_MOCK=true
```

The offline mode uses different demo accounts, seeded in
`lib/shared/mock/fixtures/`. Worth rehearsing once so you know which you're on.

---

## A demo route that shows the real work

The interesting part of this project is the **database and its access control**,
not the screens. This order shows that.

### 1. Sign in as the doctor (web)

Shows real authentication: a JWT from Supabase Auth, and a profile fetched under
row-level security.

### 2. Staff Management → add a pharmacist

This is the one flow that could not be done from the client at all. Creating
another user's account needs the service-role key, which must never ship in an
app — so it runs in an **Edge Function** that checks the caller is a doctor
server-side and provisions into *their own* clinic, ignoring whatever the
request body claims.

Verified live: a pharmacist attempting the same call is refused with
`403 Only doctors can create staff accounts.`

### 3. Sign in as the new pharmacist

They are forced to set their own password before reaching any dashboard. The
`must_change_password` flag driving that is **not writable by any client** — it
clears through a dedicated server-side function.

### 4. Sign in as a patient (mobile)

Shows the platform split, and the patient dashboard.

### 5. If asked "how do you know a patient can't read another patient's data?"

That is the strongest answer this project has, and it is testable rather than
asserted:

```bash
# supabase/tests/0015_rls_isolation_test.sql
```

It signs in as one patient and attempts to read another's profile, appointments,
metrics, goals and chats — asserting each returns zero rows *because the
database refuses*, not because the tables happen to be empty. There is a
counter-check proving the other patient's rows really do exist.

---

## What is real and what is not

Be straightforward about this — it is a sequenced migration, and the sequence is
documented.

**Backed by Postgres, live:**

- Authentication, sessions, sign-up, forced password change
- Patient / doctor / pharmacist profiles and the clinic directory
- Staff provisioning and account activation
- All 27 tables, row-level security, 15 server-side functions

**Still on the in-memory mock:** appointments, prescriptions, health metrics,
pharmacy inventory, staff scheduling, and the chatbot.

So the doctor's queue shows mock-seeded patients rather than the ones in
Postgres. That is expected at this stage — `docs/superpowers/specs/` sequences
the remaining slices, and Plan 03 (appointments) is written and ready.

---

## If something goes wrong

**"That email and password do not match"** on a seeded account — the account's
GoTrue token columns are NULL. Run:

```sql
update auth.users set
  confirmation_token = coalesce(confirmation_token, ''),
  recovery_token = coalesce(recovery_token, ''),
  email_change = coalesce(email_change, ''),
  email_change_token_new = coalesce(email_change_token_new, '')
where email like '%@mypulse360.test';
```

**Staff can't sign in on mobile / patient can't sign in on web** — that is
correct behaviour, not a bug.

**Anything network-related** — fall back to `--dart-define=MYPULSE_MOCK=true`.

**The Supabase project is paused** — free-tier projects pause when idle.
Re-activate it in the dashboard a few hours before you present, not minutes.
