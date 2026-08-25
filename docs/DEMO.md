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

**Patient (mobile, or any non-web target):**

```bash
flutter run -d windows
```

Patients are blocked from the web dashboard on purpose, so the patient app must
run on a non-web target. Windows desktop is the quickest one to demo from a
laptop; `flutter run` with a phone or emulator attached works identically. The
gate is a role check at sign-in, not a UI hint — a patient signing in on web is
signed straight back out with a message telling them to use the mobile app.

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

### 4. Sign in as a patient (non-web) and book an appointment

Shows the platform split, the patient dashboard, and the part of the system
with the most machinery behind it.

Open **Book Appointment**. The month calendar costs **one** database call, not
one per day — there is a test asserting exactly that
(`test/features/appointments/month_calendar_request_count_test.dart`), because
the saving is invisible from the screen.

Pick a day, pick a slot, confirm. Then look back at the doctor's window: the
booking appears in their queue **without a refresh**.

If you want to show the concurrency guarantee, book the same slot twice — the
second attempt is refused by a database constraint, not by application code,
and the patient is told "That time slot was just taken. Please pick another."
while the grid refreshes to the truth.

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
- **Appointment booking, rescheduling, cancellation and slot availability**
- **The patient health profile and wellness goals**
- All 27 tables, row-level security, 16 server-side functions

Two things update **without a refresh**, over Postgres realtime: the patient's
next upcoming appointment, and the doctor's queue for today.

**Still on the in-memory mock:** prescriptions, health metrics, pharmacy
inventory, staff scheduling, and the chatbot.

`docs/superpowers/specs/` sequences the remaining slices; Plan 04 takes
prescriptions and consultations next.

### Two things worth knowing before you demo

**The doctor's queue may be empty, and that is correct.** It shows appointments
scheduled for *today*. The seeded data has one appointment, and it is not today.
Book one from the patient app first and watch it appear in the doctor's queue
without a refresh — that is the realtime path, and an empty queue beforehand is
the honest starting state rather than a failure.

**Slots are generated in UTC.** The clinic's "9:00 AM" slot is 09:00 UTC. The
app never converts to local time, so a patient picks "9:00" and sees "9:00"
everywhere — it is self-consistent — but a real deployment would need a
configured clinic timezone. It is listed in `docs/PROJECT-STATUS.md` under
Known limitations.

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
