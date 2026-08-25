# Anticipated questions, and honest answers

Short answers to what a panel is most likely to ask. Every claim here is backed
by something in the repository — a test, a migration, or a document — so you can
show it rather than assert it.

---

## "Is this actually connected to a database, or is it hardcoded?"

Yes — PostgreSQL 17 on Supabase, 27 tables, 23 migrations. The quickest proof is
to book an appointment in the app and then show the row in the Supabase table
editor, or to book the same slot twice and watch the **database** refuse it.

## "Why are some features still using mock data?"

Because it is a **sequenced migration**, planned before any of it was written,
not something half-finished.

`docs/superpowers/specs/2026-08-22-supabase-backend-design.md` §9 defines nine
slices. Four are done: authentication, identity hardening, staff provisioning,
and appointments + patient profile. Prescriptions, health metrics, pharmacy
inventory, staff scheduling and the chatbot remain, and Plan 04 takes
prescriptions next.

The mock is also **deliberately retained** as two things: the test double the
119 automated tests run against, and a fully offline demo mode
(`--dart-define=MYPULSE_MOCK=true`) that works with no network at all.

The honest framing: *migrating everything at once and half-testing it would have
been worse than migrating four slices and proving each one.*

## "How do you know one patient can't read another patient's records?"

This is the strongest answer the project has, and it is testable rather than
asserted. `supabase/tests/0015_rls_isolation_test.sql` signs in as one patient
and tries to read another's profile, appointments, metrics, goals and chats —
asserting each returns zero rows *because the database refuses*.

It also contains a **counter-check proving the other patient's rows really
exist**, so the test cannot pass merely because a table is empty. That mattered:
two earlier versions of this suite passed for exactly that wrong reason and were
rewritten.

## "The API key is in your source code. Isn't that a security hole?"

No — and the distinction is the point. That is the **publishable** key. It
identifies the project, not a user, and it is meant to ship inside the client.
It is safe to commit **because row-level security stands between it and the
data** — a condition, not a property of the key.

The **service-role** key bypasses RLS entirely and is nowhere in this
repository. It exists only in the Edge Function's environment, read via
`Deno.env.get`.

## "What stops a patient from making themselves a doctor?"

Column-level grants. Row-level security decides *which rows* you can touch;
column grants decide *which columns*. The columns that carry authority —
`role`, `clinic_id`, `is_active`, `must_change_password`, `assigned_doctor_id` —
are writable by **no client at all**. Each has exactly one `SECURITY DEFINER`
function as its write path.

`profiles` also deliberately has **no INSERT policy**, and a committed test
asserts its absence, so registration cannot be moved client-side by accident.

This was found the hard way: an early version let a patient run
`update profiles set role = 'doctor'`.

## "What happens if two patients book the same slot at the same time?"

A partial unique index makes it impossible at the database level. The second
request gets Postgres error `23505`, the app translates it to *"That time slot
was just taken. Please pick another."*, and the slot grid refreshes to the
truth. Verified live today, not just in theory.

## "Is anything real-time?"

Two things, over Postgres realtime: the patient's next upcoming appointment, and
the doctor's queue for today. Book from the patient app and watch it appear in
the doctor's window without touching it.

## "Did you test it, or does it just look finished?"

- **119 automated Dart tests**, `flutter analyze` clean.
- **22 SQL test files** run against the real database.
- Every unit of work was reviewed against its specification, then the whole
  branch was reviewed again as a system.

The second review step exists for a specific reason: **nine defects in this
project were only visible where two individually-correct changes met** — a
datasource that was correct but wired to nothing, a wiring change that made
three error paths live, a deletion that would have broken the offline demo.
Neither reviewing the parts nor reviewing the whole finds those alone.

Three **defective tests** were also caught, each by refusing to make a red
assertion green without understanding it. One could never pass at all — it
matched a value PostgreSQL never emits.

## "What doesn't work / what would you fix next?"

Answer this one plainly; it is a strength, not an admission. All of it is in
`docs/PROJECT-STATUS.md` under Known limitations:

1. Five features still on the mock (above).
2. **Slots are generated in UTC**, so the clinic's "9:00 AM" is 09:00 UTC. The
   app is self-consistent — you pick 9:00 and see 9:00 — but a real deployment
   needs a configured clinic timezone. This is the first thing I would fix.
3. A deactivated staff member keeps a valid session until their token expires
   (one hour); `is_active` is checked at sign-in, not on every request.
4. No account erasure. Eight foreign keys reference `profiles` with `NO ACTION`,
   so a user with history cannot be deleted — `is_active` is the intended
   soft-delete. The app refuses the operation honestly rather than reporting a
   success that did not happen.

---

## Demo notes

**Accounts** are in `docs/DEMO.md`. Staff sign in on **web**; patients sign in
on **mobile or desktop** — a patient signing in on web is signed straight back
out, by role check, not by hiding a button.

**The doctor's queue is seeded with a clinic day in progress** — two appointments
already seen, two still to come. Those times come from `current_date` in
`supabase/seed.sql`, not a hardcoded date, so they are always "today" and never
silently rot into an empty screen.

**Best single moment to show:** book from the patient app, then look at the
doctor's window. It updates without a refresh. Then book the same slot again and
let the database refuse it.
