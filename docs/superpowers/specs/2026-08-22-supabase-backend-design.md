# MyPulse360 — Supabase Backend Design

**Date:** 2026-08-22
**Status:** Approved for planning
**Supersedes:** the in-memory `MockDatabase` as the production data source

---

## 1. Context

MyPulse360 is a Flutter clinic platform serving three roles — patient (mobile),
doctor and pharmacist (web) — from one codebase. Every feature currently reads
and writes `lib/shared/mock/mock_database.dart`, a session-lifetime in-memory
store seeded from Dart fixtures. Data vanishes on relaunch and cannot be shared
between devices, so the multi-role story the app is built around does not
actually work: a patient booking on their phone is invisible to the doctor on
the web.

`lib/config/env/env.dart` already documents the intended end state:

> `isMockMode` exists as the single switch to flip once a real Supabase backend
> is wired in.

This document designs that backend and the migration to it.

### Goals

1. A real Postgres schema covering every subsystem, with integrity enforced by
   the database rather than by Dart.
2. Real authentication and per-row authorization, such that a patient cannot
   read another patient's records even with a valid API key.
3. The full app migrated onto it — all ten subsystems, not a subset.
4. Live queue and appointment updates without a manual refresh.

### Non-goals

- Offline support / local mirroring. Explicitly declined; the app requires
  connectivity.
- Deleting the mock. It remains as the test double for the existing 91 tests.
- Redesigning the UI. The sage/slate direction in
  `design-system/mypulse360-clinic-ios/` is settled and unchanged by this work.
- Moving `health_tips` into the database. It is static content; a network round
  trip to render a tips carousel buys nothing.

---

## 2. Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Supabase hosted Postgres** | Only option where the patient mobile app and the staff web app genuinely share one backend. Matches the documented intent of `Env.isMockMode`. |
| D2 | **Full schema now, all subsystems migrated** | Foreign keys and RLS policies cannot be retrofitted sanely; a partial schema would be reworked. Migration is sequenced in slices (§9) but scoped to completion. |
| D3 | **Supabase Auth + one Edge Function** | Real JWTs let RLS use `auth.uid()`. Staff creation needs the service-role key, which must never ship in a client, so it moves server-side. |
| D4 | **Async all the way** | `Future`/`Stream` repositories and `AsyncValue` in the UI. The alternative — sync reads over a hydrated cache — silently rebuilds the mock as a cache layer, inherits stale-read bugs, and cannot report network failure. |

---

## 3. Architecture

The existing clean-architecture layering provides the seam. What changes:

| Layer | Change |
|-------|--------|
| `domain/entities/*` | **Unchanged.** Already plain value objects. |
| `domain/repositories/*` | Signatures become `Future<T>`; two become `Stream<T>` (§7). |
| `data/datasources/*` | New `Supabase*DataSource` alongside each `Mock*DataSource`. Mocks retained. |
| `data/repositories/*` | Unchanged in shape — still delegate to the injected datasource. |
| `presentation/providers/*` | `Provider` → `FutureProvider` / `StreamProvider`. Datasource selected by `Env.isMockMode`. |
| `presentation/pages`, `widgets` | Render `AsyncValue` via a shared `AsyncSection` widget. |

### Identity migration

The mock uses readable string ids (`user-dr-ahmed`, `MockIds.defaultClinicId`).
Supabase Auth issues UUIDs, and `profiles.id` is `auth.users.id`. Every table
keyed on a user id therefore moves together — which is why auth is slice 2 and
every other slice depends on it. Seed data (§8) assigns fixed UUIDs so demo
accounts are stable across re-seeds.

---

## 4. Schema

27 tables. All timestamps are `timestamptz`. All primary keys are `uuid` with
`default gen_random_uuid()` unless stated. All tables carry `created_at
timestamptz not null default now()`; mutable tables also carry `updated_at`
maintained by a shared `set_updated_at()` trigger.

### 4.1 Enum types

Postgres enums mirroring the Dart enums, so invalid values are rejected by the
database:

```
user_role            patient | doctor | pharmacist
appointment_status   scheduled | confirmed | in_progress | completed | cancelled | rescheduled
consultation_status  in_progress | completed
prescription_status  active | expiring | expired | dispensed | cancelled
prescription_source  in_app | scanned_external
metric_type          weight | blood_pressure | blood_sugar | heart_rate |
                     steps | sleep_hours | calories_burned | exercise_minutes
wellness_goal_type   exercise | hydration | sleep | diet | custom
goal_status          on_track | at_risk | excellent | behind
wastage_reason       expired | damaged | recalled | other
shift_status         scheduled | completed | missed | cancelled
leave_status         pending | approved | denied
chat_sender          user | assistant
health_platform      apple_health | google_fit
interaction_severity low | moderate | severe
```

These are transcribed from the Dart enums, not inferred — `wellness_goal_type`
and `leave_status` in particular do not match the obvious guesses
(`leave_status` has no `rejected` or `cancelled`; the value is `denied`).

Dart uses lowerCamelCase (`inProgress`); Postgres uses snake_case
(`in_progress`). Mapping lives in one place per enum in the data layer, not
scattered across datasources.

### 4.2 Identity

**`clinics`** — `id`, `name`, `address`, `phone`.

**`profiles`** — the `AppUser` table.
`id uuid pk references auth.users(id) on delete cascade`, `email citext not null
unique`, `full_name text not null`, `role user_role not null`, `clinic_id uuid
not null references clinics`, `phone text`, `avatar_url text`, `is_active
boolean not null default true`, `must_change_password boolean not null default
false`.

**`patient_profiles`** — `id uuid pk references profiles(id) on delete cascade`,
`date_of_birth date`, `gender text`, `blood_type text`, `height_cm numeric(5,2)
not null`, `weight_kg numeric(5,2) not null`, `allergies text[] not null default
'{}'`, `chronic_conditions text[] not null default '{}'`, `current_medications
text[] not null default '{}'`, `assigned_doctor_id uuid references profiles`,
`insurance_provider text`, `emergency_contact_name text`,
`emergency_contact_phone text`, `preferred_clinic_id uuid references clinics`,
`preferred_language text`, `notify_appointments boolean not null default true`,
`notify_prescriptions boolean not null default true`, `notify_health_tips
boolean not null default true`.

BMI is **not** stored — it is derived in the entity today and stays derived.

**`doctor_profiles`** — `id uuid pk references profiles(id) on delete cascade`,
`license_number text not null unique`, `specialization text not null`,
`clinic_id uuid not null references clinics`, `bio text`, `average_rating
numeric(2,1) check (average_rating between 0 and 5)`.

**`pharmacist_profiles`** — `id uuid pk references profiles(id) on delete
cascade`, `license_number text not null unique`, `pharmacy_name text not null`,
`clinic_id uuid not null references clinics`.

### 4.3 Appointments

**`doctor_availability`** — replaces the hardcoded 9–17 loop in
`mock_appointments_datasource.dart:60`.
`id`, `doctor_id uuid not null references profiles`, `weekday smallint not null
check (weekday between 0 and 6)`, `start_time time not null`, `end_time time not
null`, `slot_minutes smallint not null default 30`,
`check (end_time > start_time)`, `unique (doctor_id, weekday, start_time)`.

**`appointments`** — `id`, `patient_id uuid not null references profiles`,
`doctor_id uuid not null references profiles`, `clinic_id uuid not null
references clinics`, `scheduled_at timestamptz not null`, `duration_minutes int
not null default 30`, `appointment_type text not null`, `status
appointment_status not null default 'scheduled'`, `reason_for_visit text`,
`room_label text`.

> **Integrity — no double booking.**
> ```sql
> create unique index appointments_no_double_booking
>   on appointments (doctor_id, scheduled_at)
>   where status <> 'cancelled';
> ```
> Today two patients racing for the 10:30 slot both succeed.

> **Queue number is derived, never stored.** It is ordinal position among that
> doctor's non-cancelled appointments for that day — exactly what
> `queue_number_page.dart:79` already computes. A stored column would go stale
> the moment anyone cancels.

**`consultations`** — `id`, `appointment_id uuid not null unique references
appointments`, `patient_id`, `doctor_id`, `status consultation_status not null`,
vitals flattened (`systolic_bp int`, `diastolic_bp int`, `heart_rate int`,
`temperature_celsius numeric(4,1)`, `blood_sugar int`, `weight_kg numeric(5,2)`),
`diagnosis text`, `notes text`, `recommendations text`, `completed_at`.

`ConsultationVitals` is a value object with no identity; flattening keeps reads
to one row.

### 4.4 Prescriptions

**`prescriptions`** — `id`, `patient_id uuid not null references profiles`,
`doctor_id uuid references profiles` (**nullable** — a scanned external
prescription has no in-app prescriber), `issued_date date not null`,
`expiry_date date not null`, `status prescription_status not null`,
`consultation_id uuid references consultations`, `source prescription_source not
null`, `external_doctor_name text`,
`check (doctor_id is not null or external_doctor_name is not null)`,
`check (expiry_date >= issued_date)`.

**`prescription_items`** — `id`, `prescription_id uuid not null references
prescriptions on delete cascade`, `medication_name text not null`, `strength
text not null`, `form text not null`, `quantity int not null check (quantity >
0)`, `unit text not null`, `frequency text not null`, `duration_days int not
null`, `instructions text not null`, `refills_allowed int not null default 0`,
`sort_order smallint not null` (preserves item order).

**`drug_interactions`** — `medication_a text not null`, `medication_b text not
null`, `severity interaction_severity not null`, `description text not null`,
`primary key (medication_a, medication_b)`. Reference data, readable by all
authenticated users.

### 4.5 Health

**`health_metrics`** — `id`, `patient_id uuid not null references profiles`,
`type metric_type not null`, `value numeric not null`, `secondary_value numeric`
(diastolic, for blood pressure), `measured_at timestamptz not null`,
`recorded_by uuid references profiles`, `notes text`.
Index on `(patient_id, type, measured_at desc)` — every dashboard read is
"latest N of this type for this patient".

**`health_platform_connections`** — `patient_id uuid references profiles`,
`platform health_platform`, `connected_at`, `last_synced_at`,
`primary key (patient_id, platform)`.

**`wellness_goals`** — `id`, `patient_id`, `type wellness_goal_type not null`,
`name text not null`, `target_value numeric not null`, `current_value numeric
not null default 0`, `unit text not null`, `status goal_status not null`,
`target_date date not null`.

**`goal_progress`** — `id`, `goal_id uuid not null references wellness_goals on
delete cascade`, `log_date date not null`, `value numeric not null`, `notes
text`, `unique (goal_id, log_date)`.

### 4.6 Pharmacy

**`suppliers`** — `id`, `clinic_id uuid not null references clinics`, `name text
not null`, `contact_name text`, `phone text`, `email text`.

**`inventory_items`** — `id`, `location_id uuid not null references clinics`
(the entity's `locationId` — multi-location stock), `medication_name text not
null`, `strength text not null`, `form text not null`, `reorder_level int not
null default 0`, `unit_cost numeric(10,2) not null`, `barcode text`,
`unique (location_id, medication_name, strength, form)`.

**`inventory_batches`** — `id`, `item_id uuid not null references
inventory_items on delete cascade`, `batch_number text not null`, `quantity int
not null check (quantity >= 0)`, `initial_quantity int not null`, `expiry_date
date not null`, `unit_cost numeric(10,2) not null`, `received_date date not
null`, `supplier_id uuid references suppliers`,
`unique (item_id, batch_number)`.
Index on `(item_id, expiry_date)` — FEFO reads earliest expiry first.

**`wastage_records`** — `id`, `batch_id uuid not null references
inventory_batches`, `item_id uuid not null references inventory_items`,
`quantity int not null check (quantity > 0)`, `reason wastage_reason not null`,
`recorded_at`, `recorded_by uuid not null references profiles`, `note text`.

**`dispense_records`** — `id`, `item_id uuid not null references
inventory_items`, `quantity int not null check (quantity > 0)`, `dispensed_at`.
**Extended beyond the current entity** with nullable `batch_id uuid references
inventory_batches`, `prescription_id uuid references prescriptions`,
`dispensed_by uuid references profiles` — FEFO dispensing implies a batch, and
the entity does not record one today.

### 4.7 Scheduling

**`shifts`** — `id`, `staff_id uuid not null references profiles`, `clinic_id`,
`start_at timestamptz not null`, `end_at timestamptz not null`, `status
shift_status not null`, `notes text`, `check (end_at > start_at)`.

**`leave_requests`** — `id`, `staff_id uuid not null references profiles`,
`start_date date not null`, `end_date date not null`, `reason text not null`,
`status leave_status not null default 'pending'`, `requested_at`, `decided_by
uuid references profiles`, `decided_at`, `check (end_date >= start_date)`.

**`staff_unavailability`** — `id`, `staff_id`, `date date not null`, `reason
text`, `unique (staff_id, date)`.

**`attendance_records`** — `id`, `staff_id`, `shift_id uuid references shifts`,
`clock_in_at timestamptz not null`, `clock_out_at timestamptz`,
`check (clock_out_at is null or clock_out_at > clock_in_at)`.
Partial unique index on `(staff_id) where clock_out_at is null` — one open
clock-in per person, matching the tested behaviour in
`mock_scheduling_datasource_test.dart` ("a second clock-in while already open
returns the same open record").

**`staff_notifications`** — `id`, `staff_id`, `message text not null`,
`sent_at`, **`read_at timestamptz`** (extension: the entity has no read state).

### 4.8 Chat

**`chat_conversations`** — `id`, `patient_id uuid not null references profiles`.

**`chat_messages`** — `id`, `conversation_id uuid not null references
chat_conversations on delete cascade`, `sender chat_sender not null`, `body text
not null` (maps to `ChatMessage.text`; `text` is avoided as a column name),
`sent_at timestamptz not null`, `quick_replies text[] not null default '{}'`,
`seq bigserial` (stable ordering within a conversation).

---

## 5. Functions (RPC)

Invariants that span multiple rows live in `SECURITY DEFINER` functions, not in
the client. Direct write access to the tables they guard is revoked from
`authenticated` (§6).

**`available_slots(p_doctor uuid, p_date date) returns setof slot_row`**
Generates slots from `doctor_availability` for that weekday, left-joins
non-cancelled `appointments`, and checks approved `leave_requests` and
`staff_unavailability`. Returns `(slot_at, is_booked, is_doctor_on_leave,
is_past)` — the exact shape `TimeSlot` needs. One round trip instead of three,
and no client-side clock skew.

**`book_appointment(p_doctor uuid, p_at timestamptz, p_type text, p_reason text) returns appointments`**
Atomic. Asserts the caller is the patient, the doctor is active, the slot exists
in availability, the doctor is not on approved leave, and the slot is free; then
inserts. The unique index is the final backstop — a concurrent booking raises
`unique_violation`, which the client surfaces as "that slot was just taken"
(§7).

**`apply_leave(p_start date, p_end date, p_reason text) returns leave_requests`**
Files the request. Approval (see `decide_leave`) cancels appointments inside the
window. Mirrors `apply_leave_usecase.dart`, which has existing test coverage that
must continue to describe the same behaviour.

> **Corrected during planning.** An earlier draft of this section said approval
> notifies *affected patients* via `staff_notifications`. That is wrong twice
> over: the table is keyed `staff_id`, and the tested mock behaviour
> ("decideLeave stamps who decided and notifies the requester") notifies the
> **requesting staff member**. Patient-facing notification has no entity in the
> Dart app and is out of scope.

**`decide_leave(p_request uuid, p_status leave_status) returns leave_requests`**
Doctor-only. Stamps `decided_by`/`decided_at` and triggers the cancellation path.

**`dispense_fefo(p_item uuid, p_qty int, p_prescription uuid) returns setof dispense_records`**
Consumes batches in `expiry_date` order, decrements `quantity`, refuses if total
stock is insufficient, and writes one `dispense_records` row per batch touched.

**`clock_in()` / `clock_out()`** — enforce the one-open-record rule.

**Helpers (stable, `SECURITY DEFINER`):** `auth_role() returns user_role` and
`auth_clinic() returns uuid`, reading the caller's `profiles` row. Used by
policies so they do not recurse on `profiles` itself.

---

## 6. Security model

**Row-level security protects reads; RPC functions protect invariants.** Neither
alone suffices. RLS is enabled on all 27 tables; deny-by-default — no policy
means no access.

### Read policies (summary)

| Table group | Patient | Doctor | Pharmacist |
|---|---|---|---|
| own `profiles` row | ✓ | ✓ | ✓ |
| `doctor_directory()` fn | ✓ | ✓ | ✓ |
| `patient_profiles` | own | assigned, or has an appointment with them | via `prescription_safety()` fn only |
| `appointments` | own | own | — |
| `consultations` | own | own | — |
| `prescriptions`, `prescription_items` | own | issued by them | same clinic |
| `health_metrics`, `wellness_goals`, `goal_progress`, `health_platform_connections` | own | assigned / consulting | — |
| `chat_conversations`, `chat_messages` | own | — | — |
| `inventory_*`, `suppliers`, `wastage_records`, `dispense_records` | — | read | read + write, own clinic |
| `shifts`, `leave_requests`, `attendance_records`, `staff_unavailability`, `staff_notifications` | — | own + all staff in clinic | own |
| `drug_interactions` | ✓ | ✓ | ✓ |

### Narrowing functions (revised from views during planning)

Both are `SECURITY DEFINER` **functions**, not views. A `SECURITY DEFINER` view
is reported as an error by Supabase's own security advisor, and a design that
requires permanently explaining away a warning is a worse design. Functions
narrow identically, are callable as RPCs from Flutter, and leave the advisor
clean.

- **`doctor_directory(p_search text, p_specialization text)`** returns
  `(id, full_name, avatar_url, specialization, bio, average_rating, clinic_id)`
  for active doctors. The "Find a doctor" screen needs these; it does not need
  doctors' email or phone, which a table-level policy would have leaked.
- **`prescription_safety(p_prescription uuid)`** returns the patient's
  `allergies` and `current_medications`, and only for a prescription at the
  calling pharmacist's clinic. Dispensing safely requires allergy data; it does
  not require medical history.

### Write discipline

`INSERT`/`UPDATE`/`DELETE` on `appointments`, `leave_requests`,
`inventory_batches`, `dispense_records` and `attendance_records` are **revoked
from `authenticated`**. All writes go through the §5 functions. Without this,
the leave and collision checks are advisory: anyone holding the anon key could
insert an arbitrary row.

### Edge Function — `create-staff-account`

The only server-side code. Verifies the caller's JWT, refuses any caller whose
role is not `doctor`, then uses the service-role key to create the auth user and
the `profiles` row with `must_change_password = true`. Returns the new profile.
The service key exists only in this function's environment and is never shipped
to a client. The anon key ships in the client and is safe by design — RLS is
what protects the data.

---

## 7. Async and realtime

### Repository signatures

`Future<T>` for one-shot reads. `Stream<T>` for exactly two things, which are
the only genuinely live data in the product:

- `watchNextUpcoming(patientId)` — the dashboard's next-appointment card
- `watchTodaysQueue(doctorId)` — the queue screen and the doctor's queue

Both back onto Supabase realtime on the `appointments` table, filtered
server-side.

### Providers

`FutureProvider.family` / `StreamProvider.family`, with the datasource chosen by
`Env.isMockMode`.

**`appointmentsRevisionProvider` is deleted.** That manual refresh counter
(`appointments_providers.dart:16`) exists only because the mock had no way to
notify. Realtime plus `ref.invalidate` after a mutation replaces it, and keeping
it would mean two competing refresh mechanisms.

### UI

One shared `AsyncSection` widget renders the three states consistently, using
the existing design tokens: skeletons in `surfaceMuted`, errors using the
caution token with a retry action. Screens do not hand-roll `.when()`.

### Error taxonomy

The mock could not fail; the network can. Each case gets a defined message and
recovery:

| Case | Behaviour |
|---|---|
| Network unreachable | Retry action in `AsyncSection`; nothing destructive happens |
| Session expired / refused | Redirect to login, preserving intended route |
| **Slot taken mid-flow** | `unique_violation` from `book_appointment` → "That slot was just taken", slot grid refreshes, selection cleared |
| Insufficient stock (FEFO) | Dispense refused with the shortfall named |
| Constraint violation (other) | Generic failure message; the raw Postgres error is logged, never shown |

---

## 8. Seeding

`lib/shared/mock/fixtures/*.dart` become `supabase/seed.sql` so the app has
content and the demo logins work:

- Fixed UUIDs for demo accounts, so re-seeding is stable and foreign keys in the
  seed can be written by hand.
- Auth users created through the admin API in a seed script (SQL alone cannot
  create `auth.users` with a password), then `profiles` rows inserted to match.
- `seed_credentials.dart` demo passwords carry over so existing demo logins
  continue to work.
- `doctor_availability` seeded to 09:00–17:00, 30-minute slots, Mon–Fri,
  reproducing today's hardcoded behaviour.

---

## 9. Migration sequence

Each slice leaves the app runnable, with `Env.isMockMode` able to flip back.

| # | Slice | Notes |
|---|-------|-------|
| 1 | Project, schema, RLS, seed | No Dart changes. Reviewable in isolation. |
| 2 | Auth | Login, sign-up, forced password change, staff Edge Function. Establishes UUID identity; everything downstream depends on it. |
| 3 | **Appointments** | Availability RPC, booking RPC, realtime queue. The reference screens. |
| 4 | Prescriptions + consultations | |
| 5 | Health dashboard | Metrics, goals, progress, platform connections. |
| 6 | Pharmacy inventory | Items, batches, suppliers, wastage, FEFO dispensing. |
| 7 | Scheduling | Shifts, leave, attendance, notifications. |
| 8 | Chat | |
| 9 | Cutover | `Env.isMockMode` defaults false; mocks retained for tests only. |

---

## 10. Testing

- **Existing 91 tests keep passing unchanged.** They exercise domain usecases
  against the mock datasources, and neither changes. Any test that breaks
  signals an accidental domain change, which is the signal we want.
- **RLS tests are mandatory.** SQL tests asserting patient A cannot select
  patient B's rows across every patient-owned table, and that a pharmacist
  cannot read medical history. An RLS bug in a health app is a data breach, so
  it gets automated coverage rather than a manual click-through.
- **RPC tests** for the invariants: concurrent `book_appointment` on one slot
  yields exactly one success; `apply_leave` cancels exactly the appointments in
  range (mirroring the existing usecase tests); `dispense_fefo` consumes
  earliest expiry first and refuses on shortfall.
- **Integration** against a local stack (`supabase start`) where Docker is
  available, otherwise a dev project.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| Demo requires connectivity | Accepted deliberately (§1 non-goals). Offline was declined. |
| Migration is large; a half-done state demos badly | Slice order (§9); `Env.isMockMode` flips back to a working app at any point. |
| RLS misconfiguration leaks patient data | Automated RLS tests (§10); deny-by-default; narrow views instead of table policies for cross-role reads. |
| Enum drift between Dart and Postgres | One mapping site per enum in the data layer; a test asserting every Dart enum value maps to a Postgres label. |
| Free-tier project pauses when idle | Known Supabase behaviour; re-activate before a demo. The existing "reportly" project is already paused this way. |

---

## 12. Target project

Provisioned by the user on 2026-08-22. No creation step required.

| Field | Value |
|-------|-------|
| Name | MyPulse360 |
| Ref | `arxrtodtnrmhwbecwyxm` |
| URL | `https://arxrtodtnrmhwbecwyxm.supabase.co` |
| Region | `ap-northeast-1` |
| Postgres | 17.6 |
| State at design time | Empty — 0 tables, 0 migrations |

Remaining prerequisites:

- `supabase_flutter` added to `pubspec.yaml`.
- Publishable key + project URL in client config; service-role key only in the
  Edge Function environment, never in the repo.

### Key handling

The project uses a **publishable** key (`sb_publishable_…`), which is designed
to ship inside client applications and is safe to commit. It is safe *because*
RLS stands between it and the data — that is a condition, not a property of the
key.

> **Consequence for the migration order:** a table that exists without an RLS
> policy is fully readable and writable by anyone holding the publishable key.
> Therefore **every `create table` ships in the same migration as its `enable
> row level security` and its policies.** Slice 1 must never land tables first
> and policies second, even briefly. `get_advisors(type: security)` is run after
> each migration to catch any table left uncovered.
