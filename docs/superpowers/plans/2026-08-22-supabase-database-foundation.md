# Supabase Database Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete MyPulse360 Postgres schema — 27 tables, row-level security, six RPC functions, two narrowing functions and seed data — in Supabase project `arxrtodtnrmhwbecwyxm`, verified by SQL tests proving cross-tenant reads are impossible.

**Architecture:** Every migration is a `.sql` file committed to `supabase/migrations/`, applied through the Supabase MCP `apply_migration` tool. Tables never ship without their RLS policies in the same migration. Multi-row invariants (booking collisions, leave cancellation, FEFO dispensing) live in `SECURITY DEFINER` functions; direct writes to the tables they guard are revoked from `authenticated`.

**Tech Stack:** Postgres 17.6, Supabase RLS + Auth, SQL tests executed via the MCP `execute_sql` tool.

**Spec:** `docs/superpowers/specs/2026-08-22-supabase-backend-design.md`

**No Dart is touched in this plan.** The Flutter app continues to run against `MockDatabase` throughout. Plan 02 wires the client.

## Global Constraints

- **Project ref:** `arxrtodtnrmhwbecwyxm` — pass as `project_id` to every MCP call.
- **Every `create table` ships in the same migration as its `alter table … enable row level security` and its policies.** Never tables in one migration and policies in the next, even briefly. A table without a policy is fully readable by anyone holding the publishable key.
- **Deny by default.** RLS enabled on all 27 tables. No policy means no access.
- **No `SECURITY DEFINER` views.** Use `SECURITY DEFINER` functions for narrowing.
- Every `SECURITY DEFINER` function sets `search_path = public, pg_temp` explicitly.
- All timestamps `timestamptz`. All PKs `uuid default gen_random_uuid()` unless the spec states otherwise.
- Enum labels are **snake_case** in Postgres, lowerCamelCase in Dart. Values are transcribed verbatim from spec §4.1 — do not infer them.
- Migration files are named `NNNN_snake_case_name.sql`, numbered sequentially from `0001`.
- After each migration task, run `get_advisors(type: "security")` and resolve any ERROR-level finding before committing.
- **Slots are generated and compared in UTC.** `doctor_availability` stores wall-clock `time` values; `available_slots` anchors them with `at time zone 'UTC'` so the absolute slot never depends on the connection's TimeZone setting. Every test timestamp is written with an explicit `+00` offset. A future multi-timezone clinic would add a `timezone` column to `clinics` and anchor to that instead — out of scope here, and noted so the assumption is visible rather than accidental.

---

## Test Approach

There is no local Postgres in this environment, so tests run against the live project via `execute_sql`. Each assertion is wrapped in a transaction that impersonates a user and rolls back:

```sql
begin;
select set_config('request.jwt.claims',
                  json_build_object('sub', '<user-uuid>', 'role', 'authenticated')::text, true);
set local role authenticated;
-- assertion here
rollback;
```

Assertions return a single `status` column reading `PASS` or `FAIL`, so a result is readable at a glance:

```sql
select case when count(*) = 0 then 'PASS' else 'FAIL: ' || count(*) || ' rows leaked' end as status
from public.patient_profiles where id <> '<user-uuid>';
```

Test SQL is committed under `supabase/tests/` so it is re-runnable, not typed once into a console.

---

## Task 1: Foundation — extensions, enums, shared helpers

**Files:**
- Create: `supabase/migrations/0001_foundation.sql`
- Create: `supabase/tests/0001_foundation_test.sql`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: 14 enum types and the `public.set_updated_at()` trigger function. Every later task attaches `set_updated_at()` to its mutable tables.
- **Not** `auth_role()`/`auth_clinic()` — those moved to Task 2. See the note in Step 3.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0001_foundation_test.sql`:

```sql
-- Expect 14 enum types and the one trigger helper.
select case when count(*) = 14 then 'PASS' else 'FAIL: ' || count(*) || ' enums' end as status
from pg_type t join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public' and t.typtype = 'e';

select case when count(*) = 1 then 'PASS' else 'FAIL: ' || count(*) || ' helpers' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'set_updated_at';
```

- [ ] **Step 2: Run the test to verify it fails**

Run the file's contents through MCP `execute_sql` with `project_id: "arxrtodtnrmhwbecwyxm"`.
Expected: `FAIL: 0 enums` and `FAIL: 0 helpers`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0001_foundation.sql`:

```sql
create extension if not exists citext;

create type public.user_role            as enum ('patient','doctor','pharmacist');
create type public.appointment_status   as enum ('scheduled','confirmed','in_progress','completed','cancelled','rescheduled');
create type public.consultation_status  as enum ('in_progress','completed');
create type public.prescription_status  as enum ('active','expiring','expired','dispensed','cancelled');
create type public.prescription_source  as enum ('in_app','scanned_external');
create type public.metric_type          as enum ('weight','blood_pressure','blood_sugar','heart_rate',
                                                 'steps','sleep_hours','calories_burned','exercise_minutes');
create type public.wellness_goal_type   as enum ('exercise','hydration','sleep','diet','custom');
create type public.goal_status          as enum ('on_track','at_risk','excellent','behind');
create type public.wastage_reason       as enum ('expired','damaged','recalled','other');
create type public.shift_status         as enum ('scheduled','completed','missed','cancelled');
create type public.leave_status         as enum ('pending','approved','denied');
create type public.chat_sender          as enum ('user','assistant');
create type public.health_platform      as enum ('apple_health','google_fit');
create type public.interaction_severity as enum ('low','moderate','severe');

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
```

> **Why the helpers are not here.** `auth_role()` and `auth_clinic()` read
> `public.profiles`, which Task 2 creates. An earlier draft placed them in this
> migration, assuming Postgres resolves function bodies at call time. That holds
> only for `plpgsql`: a `language sql` body is parsed and validated against the
> catalog at `CREATE FUNCTION` time, so it fails with `42P01 undefined_table`
> and rolls back the entire migration, enums included. The helpers therefore
> live in Task 2, created after `profiles` and before the policies that call
> them. Do not "fix" this by setting `check_function_bodies = off` or by
> stubbing a `profiles` table — the ordering is the fix.

- [ ] **Step 4: Apply the migration**

MCP `apply_migration` with `project_id: "arxrtodtnrmhwbecwyxm"`, `name: "foundation"`, `query:` the file contents.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0001_foundation_test.sql`. Expected: both rows `PASS`.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0001_foundation.sql supabase/tests/0001_foundation_test.sql
git commit -m "feat(db): add enum types and the updated-at trigger helper"
```

---

## Task 2: Identity — clinics, profiles, role tables, doctor directory

**Files:**
- Create: `supabase/migrations/0002_identity.sql`
- Create: `supabase/tests/0002_identity_test.sql`

**Interfaces:**
- Consumes: `set_updated_at()`, `user_role` (Task 1)
- Produces: tables `clinics`, `profiles`, `patient_profiles`, `doctor_profiles`, `pharmacist_profiles`; `public.auth_role() returns public.user_role`; `public.auth_clinic() returns uuid`; `public.doctor_directory(p_search text, p_specialization text)` returning `(id uuid, full_name text, avatar_url text, specialization text, bio text, average_rating numeric, clinic_id uuid)`. Every later task's policies call `auth_role()`/`auth_clinic()` and reference `profiles`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0002_identity_test.sql`:

```sql
select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('clinics','profiles','patient_profiles','doctor_profiles','pharmacist_profiles');

-- Every one of those tables must have RLS enabled.
select case when count(*) = 0 then 'PASS' else 'FAIL: ' || string_agg(relname, ', ') || ' lack RLS' end as status
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  and c.relname in ('clinics','profiles','patient_profiles','doctor_profiles','pharmacist_profiles');

select case when count(*) = 1 then 'PASS' else 'FAIL: doctor_directory missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'doctor_directory';

-- The two policy helpers land here, not in Task 1: a `language sql` body is
-- validated at CREATE FUNCTION time, so they cannot exist before `profiles`.
select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 helpers' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('set_updated_at','auth_role','auth_clinic');
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 5 tables`, `FAIL: doctor_directory missing`, and `FAIL: 1 of 3 helpers`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0002_identity.sql`:

```sql
create table public.clinics (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  address    text not null,
  phone      text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  email                citext not null unique,
  full_name            text not null,
  role                 public.user_role not null,
  clinic_id            uuid not null references public.clinics(id),
  phone                text,
  avatar_url           text,
  is_active            boolean not null default true,
  must_change_password boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index profiles_clinic_role_idx on public.profiles (clinic_id, role);

create table public.patient_profiles (
  id                      uuid primary key references public.profiles(id) on delete cascade,
  date_of_birth           date,
  gender                  text,
  blood_type              text,
  height_cm               numeric(5,2) not null,
  weight_kg               numeric(5,2) not null,
  allergies               text[] not null default '{}',
  chronic_conditions      text[] not null default '{}',
  current_medications     text[] not null default '{}',
  assigned_doctor_id      uuid references public.profiles(id),
  insurance_provider      text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  preferred_clinic_id     uuid references public.clinics(id),
  preferred_language      text,
  notify_appointments     boolean not null default true,
  notify_prescriptions    boolean not null default true,
  notify_health_tips      boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create table public.doctor_profiles (
  id             uuid primary key references public.profiles(id) on delete cascade,
  license_number text not null unique,
  specialization text not null,
  clinic_id      uuid not null references public.clinics(id),
  bio            text,
  average_rating numeric(2,1) check (average_rating between 0 and 5),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table public.pharmacist_profiles (
  id             uuid primary key references public.profiles(id) on delete cascade,
  license_number text not null unique,
  pharmacy_name  text not null,
  clinic_id      uuid not null references public.clinics(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create trigger clinics_touch             before update on public.clinics             for each row execute function public.set_updated_at();
create trigger profiles_touch            before update on public.profiles            for each row execute function public.set_updated_at();
create trigger patient_profiles_touch    before update on public.patient_profiles    for each row execute function public.set_updated_at();
create trigger doctor_profiles_touch     before update on public.doctor_profiles     for each row execute function public.set_updated_at();
create trigger pharmacist_profiles_touch before update on public.pharmacist_profiles for each row execute function public.set_updated_at();

-- Created here, not in Task 1: these read `profiles`, and a `language sql`
-- body is validated against the catalog at CREATE FUNCTION time. They must also
-- exist before any policy below calls them. Definer rights are what stop the
-- policies on `profiles` from recursing.
create or replace function public.auth_role()
returns public.user_role
language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.auth_clinic()
returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select clinic_id from public.profiles where id = auth.uid()
$$;

revoke all on function public.auth_role()   from public, anon;
revoke all on function public.auth_clinic() from public, anon;
grant execute on function public.auth_role()   to authenticated;
grant execute on function public.auth_clinic() to authenticated;

alter table public.clinics             enable row level security;
alter table public.profiles            enable row level security;
alter table public.patient_profiles    enable row level security;
alter table public.doctor_profiles     enable row level security;
alter table public.pharmacist_profiles enable row level security;

-- clinics: any signed-in user may read clinics; nobody writes from a client.
create policy clinics_read on public.clinics
  for select to authenticated using (true);

-- profiles: own row always; staff may read profiles within their own clinic.
create policy profiles_read_self on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_read_clinic_staff on public.profiles
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and clinic_id = public.auth_clinic());
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- patient_profiles: the patient, or a doctor who is assigned or has an appointment.
create policy patient_profiles_read_self on public.patient_profiles
  for select to authenticated using (id = auth.uid());
create policy patient_profiles_read_assigned_doctor on public.patient_profiles
  for select to authenticated
  using (public.auth_role() = 'doctor' and assigned_doctor_id = auth.uid());
create policy patient_profiles_write_self on public.patient_profiles
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- doctor_profiles / pharmacist_profiles: own row, plus same-clinic staff visibility.
create policy doctor_profiles_read on public.doctor_profiles
  for select to authenticated
  using (id = auth.uid() or clinic_id = public.auth_clinic());
create policy doctor_profiles_update_self on public.doctor_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy pharmacist_profiles_read on public.pharmacist_profiles
  for select to authenticated
  using (id = auth.uid() or clinic_id = public.auth_clinic());
create policy pharmacist_profiles_update_self on public.pharmacist_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Doctor discovery. A definer function, not a view: it exposes exactly the
-- columns the "Find a doctor" screen needs and never email or phone.
create or replace function public.doctor_directory(
  p_search         text default null,
  p_specialization text default null
)
returns table (
  id uuid, full_name text, avatar_url text,
  specialization text, bio text, average_rating numeric, clinic_id uuid
)
language sql stable security definer set search_path = public, pg_temp as $$
  select p.id, p.full_name, p.avatar_url,
         d.specialization, d.bio, d.average_rating, p.clinic_id
  from public.profiles p
  join public.doctor_profiles d on d.id = p.id
  where p.role = 'doctor'
    and p.is_active
    and (p_search is null or p.full_name ilike '%' || p_search || '%'
                          or d.specialization ilike '%' || p_search || '%')
    and (p_specialization is null or d.specialization = p_specialization)
  order by d.average_rating desc nulls last, p.full_name
$$;

revoke all on function public.doctor_directory(text, text) from public, anon;
grant execute on function public.doctor_directory(text, text) to authenticated;
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "identity"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0002_identity_test.sql`. Expected: three `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings. Resolve any before committing.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0002_identity.sql supabase/tests/0002_identity_test.sql
git commit -m "feat(db): add identity tables, RLS helpers, policies and doctor directory"
```

- [ ] **Step 8: Harden self-update to specific columns**

Found by review of Step 3. The self-update policies above restrict which **row**
a user may update, but not which **columns**. `profiles.role` and
`profiles.clinic_id` are ordinary columns that `auth_role()` and `auth_clinic()`
read, so an authenticated patient could run
`update public.profiles set role = 'doctor' where id = auth.uid()` and
immediately satisfy `profiles_read_clinic_staff`, exposing every profile's email
and phone in that clinic.

RLS chooses rows; column grants choose columns. Authorization needs both.

`0002_identity.sql` is already applied and migrations are immutable, so this is
a new file. Create `supabase/tests/0003_identity_hardening_test.sql`:

```sql
-- authenticated must not hold UPDATE on any column that grants authority.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated may update ' || string_agg(column_name, ', ') end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('role','clinic_id','email','is_active','must_change_password');

-- ...but must still hold UPDATE on the presentational ones.
select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 editable columns' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('full_name','phone','avatar_url');

-- A doctor may edit only their bio.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: doctor may update ' || string_agg(column_name, ', ') end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'doctor_profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('license_number','specialization','clinic_id','average_rating');

-- A patient must not self-assign a doctor.
select case when count(*) = 0 then 'PASS' else 'FAIL: assigned_doctor_id is self-editable' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'patient_profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name = 'assigned_doctor_id';

-- The `for all` policy also permitted DELETE; it must be gone.
select case when count(*) = 0 then 'PASS' else 'FAIL: patient_profiles_write_self still present' end as status
from pg_policies where schemaname = 'public' and policyname = 'patient_profiles_write_self';
```

Run it — expect five `FAIL` rows. Then create
`supabase/migrations/0003_identity_hardening.sql`:

```sql
-- RLS chooses rows; column grants choose columns. 0002 had only the first half,
-- so a self-update could rewrite the very columns auth_role()/auth_clinic()
-- read to decide authorization.
revoke update on public.profiles from authenticated;
grant  update (full_name, phone, avatar_url) on public.profiles to authenticated;

-- average_rating is system-derived; licence, specialisation and clinic are
-- administrative. Only the bio is the doctor's to edit.
revoke update on public.doctor_profiles from authenticated;
grant  update (bio) on public.doctor_profiles to authenticated;

-- A pharmacist has no self-editable fields at all.
drop policy if exists pharmacist_profiles_update_self on public.pharmacist_profiles;
revoke update on public.pharmacist_profiles from authenticated;

-- `for all` also granted DELETE, which would orphan the row while the parent
-- profiles row survived. Split it into explicit insert and update policies.
-- The read path is unaffected: patient_profiles_read_self already covers select.
drop policy if exists patient_profiles_write_self on public.patient_profiles;

create policy patient_profiles_insert_self on public.patient_profiles
  for insert to authenticated
  with check (id = auth.uid());

create policy patient_profiles_update_self on public.patient_profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Patients own their medical data, but not which doctor they are assigned to.
revoke update on public.patient_profiles from authenticated;
grant update (
  date_of_birth, gender, blood_type, height_cm, weight_kg,
  allergies, chronic_conditions, current_medications,
  insurance_provider, emergency_contact_name, emergency_contact_phone,
  preferred_clinic_id, preferred_language,
  notify_appointments, notify_prescriptions, notify_health_tips
) on public.patient_profiles to authenticated;
```

Apply as `apply_migration`, `name: "identity_hardening"`. Re-run the test —
expect five `PASS` rows. Re-run `get_advisors(type: "security")`.

```bash
git add supabase/migrations/0003_identity_hardening.sql supabase/tests/0003_identity_hardening_test.sql
git commit -m "fix(db): restrict self-update to non-authority columns"
```

> The behavioural proof — an actual patient attempting the escalation and being
> refused — lands in Task 11, which is the first point real seeded users exist.
> These assertions verify the grants; Task 11 verifies the consequence.

---

## Task 3: Appointments — availability, appointments, consultations

**Files:**
- Create: `supabase/migrations/0004_appointments.sql`
- Create: `supabase/tests/0004_appointments_test.sql`

**Interfaces:**
- Consumes: `profiles`, `clinics` (Task 2); `appointment_status`, `consultation_status`, `set_updated_at()` (Task 1)
- Produces: tables `doctor_availability`, `appointments`, `consultations`; the unique index `appointments_no_double_booking`. Task 4's RPCs write to `appointments`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0004_appointments_test.sql`:

```sql
select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('doctor_availability','appointments','consultations');

select case when count(*) = 1 then 'PASS' else 'FAIL: double-booking index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'appointments_no_double_booking';

-- authenticated must NOT hold direct write grants on appointments.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated holds ' || string_agg(privilege_type, ', ') end as status
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'appointments'
  and grantee = 'authenticated' and privilege_type in ('INSERT','UPDATE','DELETE');
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 3 tables` and `FAIL: double-booking index missing`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0004_appointments.sql`:

```sql
create table public.doctor_availability (
  id           uuid primary key default gen_random_uuid(),
  doctor_id    uuid not null references public.profiles(id) on delete cascade,
  weekday      smallint not null check (weekday between 0 and 6),
  start_time   time not null,
  end_time     time not null,
  slot_minutes smallint not null default 30 check (slot_minutes > 0),
  created_at   timestamptz not null default now(),
  constraint doctor_availability_window check (end_time > start_time),
  unique (doctor_id, weekday, start_time)
);

create table public.appointments (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.profiles(id),
  doctor_id        uuid not null references public.profiles(id),
  clinic_id        uuid not null references public.clinics(id),
  scheduled_at     timestamptz not null,
  duration_minutes int not null default 30 check (duration_minutes > 0),
  appointment_type text not null,
  status           public.appointment_status not null default 'scheduled',
  reason_for_visit text,
  room_label       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Two patients racing for the same slot: exactly one wins.
create unique index appointments_no_double_booking
  on public.appointments (doctor_id, scheduled_at)
  where status <> 'cancelled';

create index appointments_patient_idx on public.appointments (patient_id, scheduled_at desc);
create index appointments_doctor_day_idx on public.appointments (doctor_id, scheduled_at);

create table public.consultations (
  id                  uuid primary key default gen_random_uuid(),
  appointment_id      uuid not null unique references public.appointments(id) on delete cascade,
  patient_id          uuid not null references public.profiles(id),
  doctor_id           uuid not null references public.profiles(id),
  status              public.consultation_status not null default 'in_progress',
  systolic_bp         int,
  diastolic_bp        int,
  heart_rate          int,
  temperature_celsius numeric(4,1),
  blood_sugar         int,
  weight_kg           numeric(5,2),
  diagnosis           text,
  notes               text,
  recommendations     text,
  completed_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger appointments_touch  before update on public.appointments  for each row execute function public.set_updated_at();
create trigger consultations_touch before update on public.consultations for each row execute function public.set_updated_at();

alter table public.doctor_availability enable row level security;
alter table public.appointments        enable row level security;
alter table public.consultations       enable row level security;

create policy doctor_availability_read on public.doctor_availability
  for select to authenticated using (true);

create policy appointments_read_own on public.appointments
  for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid());

create policy consultations_read_own on public.consultations
  for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid());
create policy consultations_write_doctor on public.consultations
  for all to authenticated
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- Writes to appointments go through book_appointment / reschedule / status RPCs
-- only (Task 4). Without this revoke the collision and leave checks are advisory.
revoke insert, update, delete on public.appointments from authenticated;

-- A doctor may read a patient's profile when they share an appointment.
create policy patient_profiles_read_by_appointment on public.patient_profiles
  for select to authenticated
  using (
    public.auth_role() = 'doctor'
    and exists (
      select 1 from public.appointments a
      where a.patient_id = public.patient_profiles.id
        and a.doctor_id = auth.uid()
    )
  );
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "appointments"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0004_appointments_test.sql`. Expected: three `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0004_appointments.sql supabase/tests/0004_appointments_test.sql
git commit -m "feat(db): add appointments schema with double-booking prevention"
```

---

## Task 4: Booking RPCs — `book_appointment` and friends

**Files:**
- Create: `supabase/migrations/0005_booking_rpcs.sql`
- Create: `supabase/tests/0005_booking_rpcs_test.sql`

**Interfaces:**
- Consumes: `appointments`, `doctor_availability` (Task 3). Calls `public.available_slots()`, which Task 8 creates — see the ordering note in Step 3.
- Produces:
  - `public.book_appointment(p_doctor uuid, p_at timestamptz, p_type text, p_reason text)` returning `public.appointments`.
  - `public.reschedule_appointment(p_appointment uuid, p_new_at timestamptz)` returning `public.appointments`.
  - `public.set_appointment_status(p_appointment uuid, p_status public.appointment_status)` returning `public.appointments`.
  - `public.queue_position(p_appointment uuid)` returning `int`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0005_booking_rpcs_test.sql`:

```sql
select case when count(*) = 4 then 'PASS' else 'FAIL: ' || count(*) || ' of 4 functions' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('book_appointment','reschedule_appointment',
                    'set_appointment_status','queue_position');
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 4 functions`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0005_booking_rpcs.sql`.

> **Ordering note.** `book_appointment` and `reschedule_appointment` call
> `public.available_slots()`, which does **not** exist yet — Task 8 creates it,
> because its body reads `leave_requests` and `staff_unavailability`.
>
> That forward reference is safe here and only here: both callers are
> `plpgsql`, whose bodies are syntax-checked but not resolved against the
> catalog at `CREATE FUNCTION` time. A `language sql` body would be resolved
> and would fail with `42P01`. This is exactly why `available_slots` itself had
> to move to Task 8 — do not move it back, and do not convert these callers to
> `language sql`.
>
> Consequence: booking cannot be *executed* until Task 8 lands. Task 4's tests
> assert the functions exist; the behavioural tests live in Task 11.

```sql
create or replace function public.book_appointment(
  p_doctor uuid,
  p_at     timestamptz,
  p_type   text,
  p_reason text default null
)
returns public.appointments
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_patient uuid := auth.uid();
  v_clinic  uuid;
  v_row     public.appointments;
begin
  if v_patient is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select clinic_id into v_clinic from public.profiles
   where id = p_doctor and role = 'doctor' and is_active;
  if v_clinic is null then
    raise exception 'doctor % is not an active doctor', p_doctor using errcode = '22023';
  end if;

  if not exists (select 1 from public.available_slots(p_doctor, p_at::date) s
                  where s.slot_at = p_at and not s.is_booked
                    and not s.is_doctor_on_leave and not s.is_past) then
    raise exception 'slot unavailable' using errcode = '23505';
  end if;

  insert into public.appointments
    (patient_id, doctor_id, clinic_id, scheduled_at, appointment_type, reason_for_visit)
  values (v_patient, p_doctor, v_clinic, p_at, p_type, p_reason)
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.reschedule_appointment(
  p_appointment uuid, p_new_at timestamptz
)
returns public.appointments
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.appointments;
begin
  select * into v_row from public.appointments where id = p_appointment;
  if v_row.id is null then
    raise exception 'appointment not found' using errcode = 'P0002';
  end if;
  if v_row.patient_id <> auth.uid() and v_row.doctor_id <> auth.uid() then
    raise exception 'not your appointment' using errcode = '42501';
  end if;
  if not exists (select 1 from public.available_slots(v_row.doctor_id, p_new_at::date) s
                  where s.slot_at = p_new_at and not s.is_booked
                    and not s.is_doctor_on_leave and not s.is_past) then
    raise exception 'slot unavailable' using errcode = '23505';
  end if;

  update public.appointments
     set scheduled_at = p_new_at, status = 'rescheduled'
   where id = p_appointment
   returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.set_appointment_status(
  p_appointment uuid, p_status public.appointment_status
)
returns public.appointments
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.appointments;
begin
  select * into v_row from public.appointments where id = p_appointment;
  if v_row.id is null then
    raise exception 'appointment not found' using errcode = 'P0002';
  end if;
  -- Patients may only cancel; doctors may set any status on their own bookings.
  if v_row.doctor_id = auth.uid() then
    null;
  elsif v_row.patient_id = auth.uid() and p_status = 'cancelled' then
    null;
  else
    raise exception 'not permitted' using errcode = '42501';
  end if;

  update public.appointments set status = p_status
   where id = p_appointment returning * into v_row;
  return v_row;
end;
$$;

-- Queue number is ordinal position that day, never stored.
create or replace function public.queue_position(p_appointment uuid)
returns int
language sql stable security definer set search_path = public, pg_temp as $$
  with target as (
    select doctor_id, scheduled_at from public.appointments where id = p_appointment
  )
  select count(*)::int
  from public.appointments a, target t
  where a.doctor_id = t.doctor_id
    and a.scheduled_at::date = t.scheduled_at::date
    and a.status <> 'cancelled'
    and a.scheduled_at <= t.scheduled_at
$$;

revoke all on function public.book_appointment(uuid, timestamptz, text, text)      from public, anon;
revoke all on function public.reschedule_appointment(uuid, timestamptz)            from public, anon;
revoke all on function public.set_appointment_status(uuid, public.appointment_status) from public, anon;
revoke all on function public.queue_position(uuid)                                 from public, anon;

grant execute on function public.book_appointment(uuid, timestamptz, text, text)      to authenticated;
grant execute on function public.reschedule_appointment(uuid, timestamptz)            to authenticated;
grant execute on function public.set_appointment_status(uuid, public.appointment_status) to authenticated;
grant execute on function public.queue_position(uuid)                                 to authenticated;
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "booking_rpcs"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0005_booking_rpcs_test.sql`. Expected: one `PASS` row.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0005_booking_rpcs.sql supabase/tests/0005_booking_rpcs_test.sql
git commit -m "feat(db): add booking, reschedule and queue-position RPCs"
```

---

## Task 5: Prescriptions — prescriptions, items, drug interactions, safety lookup

**Files:**
- Create: `supabase/migrations/0006_prescriptions.sql`
- Create: `supabase/tests/0006_prescriptions_test.sql`

**Interfaces:**
- Consumes: `profiles`, `patient_profiles`, `pharmacist_profiles` (Task 2); `consultations` (Task 3); `prescription_status`, `prescription_source`, `interaction_severity` (Task 1)
- Produces: tables `prescriptions`, `prescription_items`, `drug_interactions`; function `public.prescription_safety(p_prescription uuid)` returning `(allergies text[], current_medications text[])`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0006_prescriptions_test.sql`:

```sql
select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('prescriptions','prescription_items','drug_interactions');

select case when count(*) = 1 then 'PASS' else 'FAIL: prescription_safety missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'prescription_safety';

-- An external scanned prescription has no doctor_id, so the prescriber check must exist.
select case when count(*) = 1 then 'PASS' else 'FAIL: prescriber check missing' end as status
from pg_constraint where conname = 'prescriptions_has_prescriber';
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 3 tables`, `FAIL: prescription_safety missing`, `FAIL: prescriber check missing`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0006_prescriptions.sql`:

```sql
create table public.prescriptions (
  id                   uuid primary key default gen_random_uuid(),
  patient_id           uuid not null references public.profiles(id),
  doctor_id            uuid references public.profiles(id),
  issued_date          date not null,
  expiry_date          date not null,
  status               public.prescription_status not null default 'active',
  consultation_id      uuid references public.consultations(id),
  source               public.prescription_source not null,
  external_doctor_name text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint prescriptions_has_prescriber
    check (doctor_id is not null or external_doctor_name is not null),
  constraint prescriptions_expiry_after_issue
    check (expiry_date >= issued_date)
);
create index prescriptions_patient_idx on public.prescriptions (patient_id, issued_date desc);

create table public.prescription_items (
  id              uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  medication_name text not null,
  strength        text not null,
  form            text not null,
  quantity        int  not null check (quantity > 0),
  unit            text not null,
  frequency       text not null,
  duration_days   int  not null check (duration_days > 0),
  instructions    text not null,
  refills_allowed int  not null default 0 check (refills_allowed >= 0),
  sort_order      smallint not null default 0,
  created_at      timestamptz not null default now()
);
create index prescription_items_parent_idx on public.prescription_items (prescription_id, sort_order);

create table public.drug_interactions (
  medication_a text not null,
  medication_b text not null,
  severity     public.interaction_severity not null,
  description  text not null,
  created_at   timestamptz not null default now(),
  primary key (medication_a, medication_b)
);

create trigger prescriptions_touch before update on public.prescriptions
  for each row execute function public.set_updated_at();

alter table public.prescriptions      enable row level security;
alter table public.prescription_items enable row level security;
alter table public.drug_interactions  enable row level security;

-- Patient sees their own; issuing doctor sees theirs; pharmacists see their clinic's.
create policy prescriptions_read on public.prescriptions
  for select to authenticated
  using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or (public.auth_role() = 'pharmacist'
        and exists (select 1 from public.profiles p
                     where p.id = public.prescriptions.patient_id
                       and p.clinic_id = public.auth_clinic()))
  );

create policy prescriptions_write_doctor on public.prescriptions
  for all to authenticated
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- A patient may file a scanned external prescription for themselves.
create policy prescriptions_insert_scanned on public.prescriptions
  for insert to authenticated
  with check (patient_id = auth.uid() and source = 'scanned_external');

-- Items inherit their parent's visibility through the parent's own policies.
create policy prescription_items_read on public.prescription_items
  for select to authenticated
  using (exists (select 1 from public.prescriptions pr
                  where pr.id = public.prescription_items.prescription_id));

create policy prescription_items_write on public.prescription_items
  for all to authenticated
  using (exists (select 1 from public.prescriptions pr
                  where pr.id = public.prescription_items.prescription_id
                    and (pr.doctor_id = auth.uid() or pr.patient_id = auth.uid())))
  with check (exists (select 1 from public.prescriptions pr
                       where pr.id = public.prescription_items.prescription_id
                         and (pr.doctor_id = auth.uid() or pr.patient_id = auth.uid())));

create policy drug_interactions_read on public.drug_interactions
  for select to authenticated using (true);

-- Dispensing safely needs allergies. It does not need medical history, so this
-- returns two arrays and nothing else, and only for a prescription belonging to
-- a patient at the calling pharmacist's clinic.
create or replace function public.prescription_safety(p_prescription uuid)
returns table (allergies text[], current_medications text[])
language sql stable security definer set search_path = public, pg_temp as $$
  select pp.allergies, pp.current_medications
  from public.prescriptions pr
  join public.patient_profiles pp on pp.id = pr.patient_id
  join public.profiles pat on pat.id = pr.patient_id
  where pr.id = p_prescription
    and public.auth_role() = 'pharmacist'
    and pat.clinic_id = public.auth_clinic()
$$;

revoke all on function public.prescription_safety(uuid) from public, anon;
grant execute on function public.prescription_safety(uuid) to authenticated;
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "prescriptions"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0006_prescriptions_test.sql`. Expected: three `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0006_prescriptions.sql supabase/tests/0006_prescriptions_test.sql
git commit -m "feat(db): add prescriptions, items, interactions and safety lookup"
```

---

## Task 6: Health — metrics, platform connections, goals, progress

**Files:**
- Create: `supabase/migrations/0007_health.sql`
- Create: `supabase/tests/0007_health_test.sql`

**Interfaces:**
- Consumes: `profiles`, `patient_profiles` (Task 2); `appointments` (Task 3); `metric_type`, `health_platform`, `wellness_goal_type`, `goal_status` (Task 1)
- Produces: tables `health_metrics`, `health_platform_connections`, `wellness_goals`, `goal_progress`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0007_health_test.sql`:

```sql
select case when count(*) = 4 then 'PASS' else 'FAIL: ' || count(*) || ' of 4 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('health_metrics','health_platform_connections','wellness_goals','goal_progress');

select case when count(*) = 1 then 'PASS' else 'FAIL: dashboard index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'health_metrics_patient_type_idx';

select case when count(*) = 0 then 'PASS' else 'FAIL: ' || string_agg(relname, ', ') || ' lack RLS' end as status
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  and c.relname in ('health_metrics','health_platform_connections','wellness_goals','goal_progress');
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 4 tables`, `FAIL: dashboard index missing`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0007_health.sql`:

```sql
create table public.health_metrics (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references public.profiles(id) on delete cascade,
  type            public.metric_type not null,
  value           numeric not null,
  secondary_value numeric,
  measured_at     timestamptz not null,
  recorded_by     uuid references public.profiles(id),
  notes           text,
  created_at      timestamptz not null default now()
);
-- Every dashboard read is "latest N of this type for this patient".
create index health_metrics_patient_type_idx
  on public.health_metrics (patient_id, type, measured_at desc);

create table public.health_platform_connections (
  patient_id     uuid not null references public.profiles(id) on delete cascade,
  platform       public.health_platform not null,
  connected_at   timestamptz not null default now(),
  last_synced_at timestamptz,
  primary key (patient_id, platform)
);

create table public.wellness_goals (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references public.profiles(id) on delete cascade,
  type          public.wellness_goal_type not null,
  name          text not null,
  target_value  numeric not null,
  current_value numeric not null default 0,
  unit          text not null,
  status        public.goal_status not null default 'on_track',
  target_date   date not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index wellness_goals_patient_idx on public.wellness_goals (patient_id);

create table public.goal_progress (
  id         uuid primary key default gen_random_uuid(),
  goal_id    uuid not null references public.wellness_goals(id) on delete cascade,
  log_date   date not null,
  value      numeric not null,
  notes      text,
  created_at timestamptz not null default now(),
  unique (goal_id, log_date)
);

create trigger wellness_goals_touch before update on public.wellness_goals
  for each row execute function public.set_updated_at();

alter table public.health_metrics              enable row level security;
alter table public.health_platform_connections enable row level security;
alter table public.wellness_goals              enable row level security;
alter table public.goal_progress               enable row level security;

-- The caller owns the row, or is a doctor treating them.
create policy health_metrics_read on public.health_metrics
  for select to authenticated
  using (
    patient_id = auth.uid()
    or (public.auth_role() = 'doctor' and (
          exists (select 1 from public.patient_profiles pp
                   where pp.id = public.health_metrics.patient_id
                     and pp.assigned_doctor_id = auth.uid())
       or exists (select 1 from public.appointments a
                   where a.patient_id = public.health_metrics.patient_id
                     and a.doctor_id = auth.uid())))
  );
create policy health_metrics_write_own on public.health_metrics
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());
create policy health_metrics_insert_doctor on public.health_metrics
  for insert to authenticated
  with check (public.auth_role() = 'doctor' and recorded_by = auth.uid());

create policy health_platform_connections_own on public.health_platform_connections
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy wellness_goals_read on public.wellness_goals
  for select to authenticated
  using (
    patient_id = auth.uid()
    or (public.auth_role() = 'doctor'
        and exists (select 1 from public.patient_profiles pp
                     where pp.id = public.wellness_goals.patient_id
                       and pp.assigned_doctor_id = auth.uid()))
  );
create policy wellness_goals_write_own on public.wellness_goals
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy goal_progress_all on public.goal_progress
  for all to authenticated
  using (exists (select 1 from public.wellness_goals g
                  where g.id = public.goal_progress.goal_id and g.patient_id = auth.uid()))
  with check (exists (select 1 from public.wellness_goals g
                       where g.id = public.goal_progress.goal_id and g.patient_id = auth.uid()));
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "health"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0007_health_test.sql`. Expected: three `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0007_health.sql supabase/tests/0007_health_test.sql
git commit -m "feat(db): add health metrics, goals and progress with RLS"
```

---

## Task 7: Pharmacy — suppliers, items, batches, wastage, FEFO dispensing

**Files:**
- Create: `supabase/migrations/0008_pharmacy.sql`
- Create: `supabase/tests/0008_pharmacy_test.sql`

**Interfaces:**
- Consumes: `clinics`, `profiles` (Task 2); `prescriptions` (Task 5); `wastage_reason` (Task 1)
- Produces: tables `suppliers`, `inventory_items`, `inventory_batches`, `wastage_records`, `dispense_records`; function `public.dispense_fefo(p_item uuid, p_qty int, p_prescription uuid)` returning `setof public.dispense_records`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0008_pharmacy_test.sql`:

```sql
select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('suppliers','inventory_items','inventory_batches','wastage_records','dispense_records');

select case when count(*) = 1 then 'PASS' else 'FAIL: FEFO index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'inventory_batches_fefo_idx';

select case when count(*) = 1 then 'PASS' else 'FAIL: dispense_fefo missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'dispense_fefo';
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 5 tables`, `FAIL: FEFO index missing`, `FAIL: dispense_fefo missing`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0008_pharmacy.sql`:

```sql
create table public.suppliers (
  id           uuid primary key default gen_random_uuid(),
  clinic_id    uuid not null references public.clinics(id),
  name         text not null,
  contact_name text,
  phone        text,
  email        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.inventory_items (
  id              uuid primary key default gen_random_uuid(),
  location_id     uuid not null references public.clinics(id),
  medication_name text not null,
  strength        text not null,
  form            text not null,
  reorder_level   int  not null default 0 check (reorder_level >= 0),
  unit_cost       numeric(10,2) not null check (unit_cost >= 0),
  barcode         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (location_id, medication_name, strength, form)
);

create table public.inventory_batches (
  id               uuid primary key default gen_random_uuid(),
  item_id          uuid not null references public.inventory_items(id) on delete cascade,
  batch_number     text not null,
  quantity         int  not null check (quantity >= 0),
  initial_quantity int  not null check (initial_quantity >= 0),
  expiry_date      date not null,
  unit_cost        numeric(10,2) not null check (unit_cost >= 0),
  received_date    date not null,
  supplier_id      uuid references public.suppliers(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (item_id, batch_number)
);
-- FEFO reads earliest expiry first.
create index inventory_batches_fefo_idx on public.inventory_batches (item_id, expiry_date);

create table public.wastage_records (
  id          uuid primary key default gen_random_uuid(),
  batch_id    uuid not null references public.inventory_batches(id),
  item_id     uuid not null references public.inventory_items(id),
  quantity    int  not null check (quantity > 0),
  reason      public.wastage_reason not null,
  recorded_at timestamptz not null default now(),
  recorded_by uuid not null references public.profiles(id),
  note        text
);

create table public.dispense_records (
  id              uuid primary key default gen_random_uuid(),
  item_id         uuid not null references public.inventory_items(id),
  quantity        int  not null check (quantity > 0),
  dispensed_at    timestamptz not null default now(),
  batch_id        uuid references public.inventory_batches(id),
  prescription_id uuid references public.prescriptions(id),
  dispensed_by    uuid references public.profiles(id)
);

create trigger suppliers_touch         before update on public.suppliers         for each row execute function public.set_updated_at();
create trigger inventory_items_touch   before update on public.inventory_items   for each row execute function public.set_updated_at();
create trigger inventory_batches_touch before update on public.inventory_batches for each row execute function public.set_updated_at();

alter table public.suppliers         enable row level security;
alter table public.inventory_items   enable row level security;
alter table public.inventory_batches enable row level security;
alter table public.wastage_records   enable row level security;
alter table public.dispense_records  enable row level security;

-- Staff read their own clinic's stock; only pharmacists write it.
create policy suppliers_read on public.suppliers
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and clinic_id = public.auth_clinic());
create policy suppliers_write on public.suppliers
  for all to authenticated
  using (public.auth_role() = 'pharmacist' and clinic_id = public.auth_clinic())
  with check (public.auth_role() = 'pharmacist' and clinic_id = public.auth_clinic());

create policy inventory_items_read on public.inventory_items
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and location_id = public.auth_clinic());
create policy inventory_items_write on public.inventory_items
  for all to authenticated
  using (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic())
  with check (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic());

create policy inventory_batches_read on public.inventory_batches
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist')
         and exists (select 1 from public.inventory_items i
                      where i.id = public.inventory_batches.item_id
                        and i.location_id = public.auth_clinic()));
create policy inventory_batches_write on public.inventory_batches
  for all to authenticated
  using (public.auth_role() = 'pharmacist'
         and exists (select 1 from public.inventory_items i
                      where i.id = public.inventory_batches.item_id
                        and i.location_id = public.auth_clinic()))
  with check (public.auth_role() = 'pharmacist'
         and exists (select 1 from public.inventory_items i
                      where i.id = public.inventory_batches.item_id
                        and i.location_id = public.auth_clinic()));

create policy wastage_records_read on public.wastage_records
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist')
         and exists (select 1 from public.inventory_items i
                      where i.id = public.wastage_records.item_id
                        and i.location_id = public.auth_clinic()));
create policy wastage_records_insert on public.wastage_records
  for insert to authenticated
  with check (public.auth_role() = 'pharmacist' and recorded_by = auth.uid());

create policy dispense_records_read on public.dispense_records
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist')
         and exists (select 1 from public.inventory_items i
                      where i.id = public.dispense_records.item_id
                        and i.location_id = public.auth_clinic()));

-- Stock decrements go through the RPC so batch quantity can never drift from
-- the dispense log.
revoke insert, update, delete on public.dispense_records from authenticated;

create or replace function public.dispense_fefo(
  p_item         uuid,
  p_qty          int,
  p_prescription uuid default null
)
returns setof public.dispense_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_remaining int := p_qty;
  v_take      int;
  v_batch     record;
  v_total     int;
begin
  if public.auth_role() <> 'pharmacist' then
    raise exception 'only pharmacists may dispense' using errcode = '42501';
  end if;
  if p_qty <= 0 then
    raise exception 'quantity must be positive' using errcode = '22023';
  end if;

  select coalesce(sum(b.quantity), 0) into v_total
  from public.inventory_batches b
  join public.inventory_items i on i.id = b.item_id
  where b.item_id = p_item
    and i.location_id = public.auth_clinic()
    and b.expiry_date >= current_date;

  if v_total < p_qty then
    raise exception 'insufficient stock: % available, % requested', v_total, p_qty
      using errcode = '23514';
  end if;

  for v_batch in
    select b.id, b.quantity
    from public.inventory_batches b
    join public.inventory_items i on i.id = b.item_id
    where b.item_id = p_item
      and i.location_id = public.auth_clinic()
      and b.expiry_date >= current_date
      and b.quantity > 0
    order by b.expiry_date, b.received_date
    for update
  loop
    exit when v_remaining <= 0;
    v_take := least(v_batch.quantity, v_remaining);

    update public.inventory_batches
       set quantity = quantity - v_take
     where id = v_batch.id;

    return query
      insert into public.dispense_records
        (item_id, quantity, batch_id, prescription_id, dispensed_by)
      values (p_item, v_take, v_batch.id, p_prescription, auth.uid())
      returning *;

    v_remaining := v_remaining - v_take;
  end loop;

  return;
end;
$$;

revoke all on function public.dispense_fefo(uuid, int, uuid) from public, anon;
grant execute on function public.dispense_fefo(uuid, int, uuid) to authenticated;
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "pharmacy"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0008_pharmacy_test.sql`. Expected: three `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0008_pharmacy.sql supabase/tests/0008_pharmacy_test.sql
git commit -m "feat(db): add pharmacy inventory with FEFO dispensing"
```

---

## Task 8: Scheduling — shifts, leave, unavailability, attendance, notifications

**Files:**
- Create: `supabase/migrations/0009_scheduling.sql`
- Create: `supabase/tests/0009_scheduling_test.sql`

**Interfaces:**
- Consumes: `profiles`, `clinics` (Task 2); `appointments` (Task 3); `shift_status`, `leave_status` (Task 1)
- Produces: tables `shifts`, `leave_requests`, `staff_unavailability`, `attendance_records`, `staff_notifications`; functions `public.apply_leave(p_start date, p_end date, p_reason text)` returning `public.leave_requests`, `public.decide_leave(p_request uuid, p_status public.leave_status)` returning `public.leave_requests`, `public.clock_in(p_shift uuid)` and `public.clock_out()` both returning `public.attendance_records`.
- **This task also creates `public.available_slots(p_doctor uuid, p_date date)`** returning `(slot_at timestamptz, is_booked boolean, is_doctor_on_leave boolean, is_past boolean)` — the exact shape Dart's `TimeSlot` needs. It lives here because its `language sql` body reads this task's tables. Task 4's `book_appointment` has been calling it all along; after this task lands, booking is executable.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0009_scheduling_test.sql`:

```sql
select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('shifts','leave_requests','staff_unavailability','attendance_records','staff_notifications');

-- One open clock-in per person, matching mock_scheduling_datasource_test.dart.
select case when count(*) = 1 then 'PASS' else 'FAIL: open-attendance index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'attendance_one_open_per_staff';

select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 functions' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('apply_leave','decide_leave','clock_in','clock_out','available_slots');

-- available_slots must return the four columns Dart's TimeSlot maps from.
select case when count(*) = 4 then 'PASS' else 'FAIL: wrong column set' end as status
from information_schema.routines r
join information_schema.parameters pa on pa.specific_name = r.specific_name
where r.routine_schema = 'public' and r.routine_name = 'available_slots'
  and pa.parameter_mode = 'TABLE'
  and pa.parameter_name in ('slot_at','is_booked','is_doctor_on_leave','is_past');
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 5 tables`, `FAIL: open-attendance index missing`, `FAIL: 0 of 5 functions`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0009_scheduling.sql`:

```sql
create table public.shifts (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.profiles(id) on delete cascade,
  clinic_id  uuid not null references public.clinics(id),
  start_at   timestamptz not null,
  end_at     timestamptz not null,
  status     public.shift_status not null default 'scheduled',
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shifts_window check (end_at > start_at)
);
create index shifts_staff_idx on public.shifts (staff_id, start_at);

create table public.leave_requests (
  id           uuid primary key default gen_random_uuid(),
  staff_id     uuid not null references public.profiles(id) on delete cascade,
  start_date   date not null,
  end_date     date not null,
  reason       text not null,
  status       public.leave_status not null default 'pending',
  requested_at timestamptz not null default now(),
  decided_by   uuid references public.profiles(id),
  decided_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint leave_window check (end_date >= start_date)
);
create index leave_requests_staff_idx on public.leave_requests (staff_id, start_date);

create table public.staff_unavailability (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.profiles(id) on delete cascade,
  date       date not null,
  reason     text,
  created_at timestamptz not null default now(),
  unique (staff_id, date)
);

create table public.attendance_records (
  id           uuid primary key default gen_random_uuid(),
  staff_id     uuid not null references public.profiles(id) on delete cascade,
  shift_id     uuid references public.shifts(id),
  clock_in_at  timestamptz not null default now(),
  clock_out_at timestamptz,
  created_at   timestamptz not null default now(),
  constraint attendance_window check (clock_out_at is null or clock_out_at > clock_in_at)
);
-- A second clock-in while one is open must be impossible.
create unique index attendance_one_open_per_staff
  on public.attendance_records (staff_id) where clock_out_at is null;

create table public.staff_notifications (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.profiles(id) on delete cascade,
  message    text not null,
  sent_at    timestamptz not null default now(),
  read_at    timestamptz
);
create index staff_notifications_staff_idx on public.staff_notifications (staff_id, sent_at desc);

create trigger shifts_touch         before update on public.shifts         for each row execute function public.set_updated_at();
create trigger leave_requests_touch before update on public.leave_requests for each row execute function public.set_updated_at();

alter table public.shifts               enable row level security;
alter table public.leave_requests       enable row level security;
alter table public.staff_unavailability enable row level security;
alter table public.attendance_records   enable row level security;
alter table public.staff_notifications  enable row level security;

-- Staff see their own rows; doctors act as managers for their clinic.
create policy shifts_read on public.shifts
  for select to authenticated
  using (staff_id = auth.uid()
         or (public.auth_role() = 'doctor' and clinic_id = public.auth_clinic()));
create policy shifts_write_manager on public.shifts
  for all to authenticated
  using (public.auth_role() = 'doctor' and clinic_id = public.auth_clinic())
  with check (public.auth_role() = 'doctor' and clinic_id = public.auth_clinic());

create policy leave_requests_read on public.leave_requests
  for select to authenticated
  using (staff_id = auth.uid()
         or (public.auth_role() = 'doctor'
             and exists (select 1 from public.profiles p
                          where p.id = public.leave_requests.staff_id
                            and p.clinic_id = public.auth_clinic())));

-- Filing and deciding leave both go through RPCs, because approving leave has
-- to cancel appointments in the same transaction.
revoke insert, update, delete on public.leave_requests from authenticated;

create policy staff_unavailability_read on public.staff_unavailability
  for select to authenticated using (true);
create policy staff_unavailability_write_own on public.staff_unavailability
  for all to authenticated
  using (staff_id = auth.uid()) with check (staff_id = auth.uid());

create policy attendance_read on public.attendance_records
  for select to authenticated
  using (staff_id = auth.uid()
         or (public.auth_role() = 'doctor'
             and exists (select 1 from public.profiles p
                          where p.id = public.attendance_records.staff_id
                            and p.clinic_id = public.auth_clinic())));
revoke insert, update, delete on public.attendance_records from authenticated;

create policy staff_notifications_read_own on public.staff_notifications
  for select to authenticated using (staff_id = auth.uid());
create policy staff_notifications_mark_read on public.staff_notifications
  for update to authenticated
  using (staff_id = auth.uid()) with check (staff_id = auth.uid());

-- Lives here, not in Task 4: this is a `language sql` body, so Postgres
-- resolves `leave_requests` and `staff_unavailability` against the catalog at
-- CREATE FUNCTION time. It cannot be created before those tables exist.
-- Task 4's book_appointment already calls it; that is legal because plpgsql
-- bodies are not resolved until run time.
create or replace function public.available_slots(p_doctor uuid, p_date date)
returns table (
  slot_at timestamptz, is_booked boolean,
  is_doctor_on_leave boolean, is_past boolean
)
language sql stable security definer set search_path = public, pg_temp as $$
  with avail as (
    select start_time, end_time, slot_minutes
    from public.doctor_availability
    where doctor_id = p_doctor
      and weekday = extract(isodow from p_date)::smallint - 1
  ),
  on_leave as (
    select exists (
      select 1 from public.leave_requests l
      where l.staff_id = p_doctor and l.status = 'approved'
        and p_date between l.start_date and l.end_date
    ) or exists (
      select 1 from public.staff_unavailability u
      where u.staff_id = p_doctor and u.date = p_date
    ) as flag
  ),
  slots as (
    -- `p_date + start_time` is a timestamp WITHOUT time zone. Left implicit,
    -- the cast to timestamptz would use the connection's TimeZone setting, so
    -- two clients in different zones would compute different absolute slots.
    -- Anchor to UTC explicitly; `appointments.scheduled_at` is timestamptz.
    select generate_series(
             (p_date + a.start_time) at time zone 'UTC',
             (p_date + a.end_time) at time zone 'UTC' - make_interval(mins => a.slot_minutes),
             make_interval(mins => a.slot_minutes)
           ) as slot_at
    from avail a
  )
  select s.slot_at,
         exists (
           select 1 from public.appointments ap
           where ap.doctor_id = p_doctor
             and ap.scheduled_at = s.slot_at
             and ap.status <> 'cancelled'
         ) as is_booked,
         (select flag from on_leave) as is_doctor_on_leave,
         s.slot_at < now() as is_past
  from slots s
  order by s.slot_at
$$;

create or replace function public.apply_leave(
  p_start date, p_end date, p_reason text
)
returns public.leave_requests
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.leave_requests;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if public.auth_role() = 'patient' then
    raise exception 'patients do not file leave' using errcode = '42501';
  end if;
  if p_end < p_start then
    raise exception 'end date precedes start date' using errcode = '22023';
  end if;

  insert into public.leave_requests (staff_id, start_date, end_date, reason)
  values (auth.uid(), p_start, p_end, p_reason)
  returning * into v_row;

  return v_row;
end;
$$;

-- Approving leave cancels the appointments it collides with and tells the
-- affected patients, in one transaction. This mirrors apply_leave_usecase.dart.
create or replace function public.decide_leave(
  p_request uuid, p_status public.leave_status
)
returns public.leave_requests
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_row       public.leave_requests;
  v_cancelled int := 0;
begin
  if public.auth_role() <> 'doctor' then
    raise exception 'only doctors decide leave' using errcode = '42501';
  end if;
  if p_status = 'pending' then
    raise exception 'decision must be approved or denied' using errcode = '22023';
  end if;

  update public.leave_requests
     set status = p_status, decided_by = auth.uid(), decided_at = now()
   where id = p_request
   returning * into v_row;

  if v_row.id is null then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;

  if p_status = 'approved' then
    update public.appointments
       set status = 'cancelled'
     where doctor_id = v_row.staff_id
       and status <> 'cancelled'
       and scheduled_at::date between v_row.start_date and v_row.end_date;

    get diagnostics v_cancelled = row_count;
  end if;

  -- Notify the requester, matching the tested mock behaviour
  -- ("decideLeave stamps who decided and notifies the requester").
  -- staff_notifications is keyed by staff_id; patient-facing notification is
  -- a separate concern with no entity in the app yet, so it is not done here.
  insert into public.staff_notifications (staff_id, message)
  values (v_row.staff_id,
          'Your leave request for '
          || to_char(v_row.start_date, 'DD Mon YYYY') || ' to '
          || to_char(v_row.end_date, 'DD Mon YYYY')
          || ' was ' || p_status::text
          || case when p_status = 'approved'
                  then '. ' || v_cancelled || ' appointment(s) were cancelled.'
                  else '.' end);

  return v_row;
end;
$$;

create or replace function public.clock_in(p_shift uuid default null)
returns public.attendance_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.attendance_records;
begin
  -- An already-open record is returned as-is rather than raising, matching the
  -- tested mock behaviour.
  select * into v_row from public.attendance_records
   where staff_id = auth.uid() and clock_out_at is null;
  if v_row.id is not null then
    return v_row;
  end if;

  insert into public.attendance_records (staff_id, shift_id)
  values (auth.uid(), p_shift)
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.clock_out()
returns public.attendance_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.attendance_records;
begin
  update public.attendance_records
     set clock_out_at = now()
   where staff_id = auth.uid() and clock_out_at is null
   returning * into v_row;

  if v_row.id is null then
    raise exception 'no open attendance record' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

revoke all on function public.available_slots(uuid, date)                  from public, anon;
revoke all on function public.apply_leave(date, date, text)                from public, anon;
revoke all on function public.decide_leave(uuid, public.leave_status)      from public, anon;
revoke all on function public.clock_in(uuid)                               from public, anon;
revoke all on function public.clock_out()                                  from public, anon;

grant execute on function public.available_slots(uuid, date)               to authenticated;
grant execute on function public.apply_leave(date, date, text)             to authenticated;
grant execute on function public.decide_leave(uuid, public.leave_status)   to authenticated;
grant execute on function public.clock_in(uuid)                            to authenticated;
grant execute on function public.clock_out()                               to authenticated;
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "scheduling"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0009_scheduling_test.sql`. Expected: four `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0009_scheduling.sql supabase/tests/0009_scheduling_test.sql
git commit -m "feat(db): add scheduling tables, leave/attendance RPCs and available_slots"
```

---

## Task 9: Chat — conversations and messages

**Files:**
- Create: `supabase/migrations/0010_chat.sql`
- Create: `supabase/tests/0010_chat_test.sql`

**Interfaces:**
- Consumes: `profiles` (Task 2); `chat_sender` (Task 1)
- Produces: tables `chat_conversations`, `chat_messages`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0010_chat_test.sql`:

```sql
select case when count(*) = 2 then 'PASS' else 'FAIL: ' || count(*) || ' of 2 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('chat_conversations','chat_messages');

-- ChatMessage.text maps to a column named body; `text` is avoided as a name.
select case when count(*) = 1 then 'PASS' else 'FAIL: body column missing' end as status
from information_schema.columns
where table_schema = 'public' and table_name = 'chat_messages' and column_name = 'body';
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 2 tables`, `FAIL: body column missing`.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0010_chat.sql`:

```sql
create table public.chat_conversations (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index chat_conversations_patient_idx on public.chat_conversations (patient_id, updated_at desc);

create table public.chat_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender          public.chat_sender not null,
  body            text not null,
  sent_at         timestamptz not null default now(),
  quick_replies   text[] not null default '{}',
  seq             bigserial
);
create index chat_messages_conversation_idx on public.chat_messages (conversation_id, seq);

create trigger chat_conversations_touch before update on public.chat_conversations
  for each row execute function public.set_updated_at();

alter table public.chat_conversations enable row level security;
alter table public.chat_messages      enable row level security;

-- A patient's health conversation is theirs alone. No staff read path.
create policy chat_conversations_own on public.chat_conversations
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy chat_messages_own on public.chat_messages
  for all to authenticated
  using (exists (select 1 from public.chat_conversations c
                  where c.id = public.chat_messages.conversation_id
                    and c.patient_id = auth.uid()))
  with check (exists (select 1 from public.chat_conversations c
                       where c.id = public.chat_messages.conversation_id
                         and c.patient_id = auth.uid()));
```

- [ ] **Step 4: Apply the migration**

MCP `apply_migration`, `name: "chat"`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0010_chat_test.sql`. Expected: two `PASS` rows.

- [ ] **Step 6: Check security advisors**

MCP `get_advisors` with `type: "security"`. Expected: no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0010_chat.sql supabase/tests/0010_chat_test.sql
git commit -m "feat(db): add chat conversations and messages"
```

---

## Task 10: Seed data

**Files:**
- Create: `supabase/seed.sql`
- Create: `supabase/tests/0011_seed_test.sql`
- Read for reference: `lib/shared/mock/fixtures/*.dart`, `lib/shared/mock/mock_ids.dart`

**Interfaces:**
- Consumes: every table from Tasks 2–9
- Produces: fixed demo UUIDs used by later plans' integration tests:
  - clinic A `11111111-1111-1111-1111-111111111111`
  - clinic B `11111111-1111-1111-1111-111111111112`
  - Dr. Ahmed Rashid `22222222-2222-2222-2222-222222222221`
  - Dr. Lina Fernandez `22222222-2222-2222-2222-222222222222`
  - pharmacist Nur Hakim `33333333-3333-3333-3333-333333333331`
  - patient Aisha Rahman `44444444-4444-4444-4444-444444444441`
  - patient Daniel Okafor `44444444-4444-4444-4444-444444444442`

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0011_seed_test.sql`:

```sql
select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 demo users' end as status
from public.profiles
where id in ('22222222-2222-2222-2222-222222222221','22222222-2222-2222-2222-222222222222',
             '33333333-3333-3333-3333-333333333331','44444444-4444-4444-4444-444444444441',
             '44444444-4444-4444-4444-444444444442');

-- Every demo profile needs a matching auth user or login fails.
select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 auth users' end as status
from auth.users u join public.profiles p on p.id = u.id;

-- Weekday availability for both doctors: 5 days x 2 doctors.
select case when count(*) = 10 then 'PASS' else 'FAIL: ' || count(*) || ' availability rows' end as status
from public.doctor_availability;
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `FAIL: 0 of 5 demo users`.

- [ ] **Step 3: Write the seed**

Create `supabase/seed.sql`. Auth users are inserted directly because SQL alone cannot call the admin API; `extensions.crypt` hashes the password the same way GoTrue does, and the matching `auth.identities` row is what makes email/password login work.

```sql
-- Demo passwords match lib/shared/mock/fixtures/seed_credentials.dart.
insert into public.clinics (id, name, address, phone) values
  ('11111111-1111-1111-1111-111111111111', 'MyPulse360 Clinic',   '12 Wellness Ave', '+1 555-0100'),
  ('11111111-1111-1111-1111-111111111112', 'MyPulse360 Downtown', '48 Market St',    '+1 555-0177')
on conflict (id) do nothing;

create or replace function pg_temp.seed_user(
  p_id uuid, p_email text, p_password text
) returns void language plpgsql as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    p_email, extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
  ) on conflict (id) do nothing;

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    p_id::text, p_id,
    jsonb_build_object('sub', p_id::text, 'email', p_email),
    'email', now(), now(), now()
  ) on conflict (provider, provider_id) do nothing;
end;
$$;

select pg_temp.seed_user('22222222-2222-2222-2222-222222222221', 'ahmed.rashid@mypulse360.test',  'Doctor123!');
select pg_temp.seed_user('22222222-2222-2222-2222-222222222222', 'lina.fernandez@mypulse360.test','Doctor123!');
select pg_temp.seed_user('33333333-3333-3333-3333-333333333331', 'nur.hakim@mypulse360.test',     'Pharma123!');
select pg_temp.seed_user('44444444-4444-4444-4444-444444444441', 'aisha.rahman@mypulse360.test',  'Patient123!');
select pg_temp.seed_user('44444444-4444-4444-4444-444444444442', 'daniel.okafor@mypulse360.test', 'Patient123!');

insert into public.profiles (id, email, full_name, role, clinic_id, phone) values
  ('22222222-2222-2222-2222-222222222221','ahmed.rashid@mypulse360.test',  'Dr. Ahmed Rashid',   'doctor',    '11111111-1111-1111-1111-111111111111','+1 555-0111'),
  ('22222222-2222-2222-2222-222222222222','lina.fernandez@mypulse360.test','Dr. Lina Fernandez', 'doctor',    '11111111-1111-1111-1111-111111111111','+1 555-0112'),
  ('33333333-3333-3333-3333-333333333331','nur.hakim@mypulse360.test',     'Nur Hakim',          'pharmacist','11111111-1111-1111-1111-111111111111','+1 555-0131'),
  ('44444444-4444-4444-4444-444444444441','aisha.rahman@mypulse360.test',  'Aisha Rahman',       'patient',   '11111111-1111-1111-1111-111111111111','+1 555-0141'),
  ('44444444-4444-4444-4444-444444444442','daniel.okafor@mypulse360.test', 'Daniel Okafor',      'patient',   '11111111-1111-1111-1111-111111111111','+1 555-0142')
on conflict (id) do nothing;

insert into public.doctor_profiles (id, license_number, specialization, clinic_id, bio, average_rating) values
  ('22222222-2222-2222-2222-222222222221','MD-10021','General practice','11111111-1111-1111-1111-111111111111',
   'Dr. Rashid has practised family and general medicine for twelve years and has been with MyPulse360 Clinic since 2019.', 4.9),
  ('22222222-2222-2222-2222-222222222222','MD-10022','Family medicine','11111111-1111-1111-1111-111111111111',
   'Dr. Fernandez focuses on preventive care and chronic condition management.', 4.8)
on conflict (id) do nothing;

insert into public.pharmacist_profiles (id, license_number, pharmacy_name, clinic_id) values
  ('33333333-3333-3333-3333-333333333331','RP-30011','MyPulse360 Pharmacy','11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

insert into public.patient_profiles
  (id, date_of_birth, gender, blood_type, height_cm, weight_kg, allergies, chronic_conditions,
   current_medications, assigned_doctor_id, preferred_clinic_id) values
  ('44444444-4444-4444-4444-444444444441','1996-04-12','Female','O+',165.0,61.0,
   '{Penicillin}','{}','{}','22222222-2222-2222-2222-222222222221','11111111-1111-1111-1111-111111111111'),
  ('44444444-4444-4444-4444-444444444442','1988-11-03','Male','A-',178.0,84.5,
   '{}','{Type 2 diabetes}','{Metformin}','22222222-2222-2222-2222-222222222221','11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

-- 09:00-17:00, 30-minute slots, Monday to Friday: reproduces the hardcoded
-- loop in mock_appointments_datasource.dart.
insert into public.doctor_availability (doctor_id, weekday, start_time, end_time, slot_minutes)
select d.id, w.weekday, time '09:00', time '17:00', 30
from (values ('22222222-2222-2222-2222-222222222221'::uuid),
             ('22222222-2222-2222-2222-222222222222'::uuid)) as d(id),
     generate_series(0, 4) as w(weekday)
on conflict (doctor_id, weekday, start_time) do nothing;

insert into public.drug_interactions (medication_a, medication_b, severity, description) values
  ('Warfarin','Aspirin','severe','Markedly increased bleeding risk when taken together.'),
  ('Metformin','Contrast dye','moderate','Withhold metformin around contrast imaging.'),
  ('Amoxicillin','Methotrexate','moderate','Reduced methotrexate clearance; monitor levels.')
on conflict (medication_a, medication_b) do nothing;

insert into public.inventory_items (id, location_id, medication_name, strength, form, reorder_level, unit_cost, barcode) values
  ('55555555-5555-5555-5555-555555555551','11111111-1111-1111-1111-111111111111','Metformin','500 mg','Tablet',50,0.12,'9551234500011'),
  ('55555555-5555-5555-5555-555555555552','11111111-1111-1111-1111-111111111111','Amoxicillin','250 mg','Capsule',40,0.31,'9551234500028')
on conflict (id) do nothing;

insert into public.suppliers (id, clinic_id, name, contact_name, phone, email) values
  ('66666666-6666-6666-6666-666666666661','11111111-1111-1111-1111-111111111111','Meridian Pharma','Sofia Lim','+1 555-0201','orders@meridian.test')
on conflict (id) do nothing;

-- Two batches per item with different expiries, so FEFO order is observable.
insert into public.inventory_batches
  (item_id, batch_number, quantity, initial_quantity, expiry_date, unit_cost, received_date, supplier_id) values
  ('55555555-5555-5555-5555-555555555551','MET-2025-A',120,200,'2027-03-31',0.12,'2026-06-01','66666666-6666-6666-6666-666666666661'),
  ('55555555-5555-5555-5555-555555555551','MET-2025-B',300,300,'2027-11-30',0.12,'2026-07-15','66666666-6666-6666-6666-666666666661'),
  ('55555555-5555-5555-5555-555555555552','AMX-2026-A',80,150,'2027-01-31',0.31,'2026-05-20','66666666-6666-6666-6666-666666666661')
on conflict (item_id, batch_number) do nothing;
```

- [ ] **Step 4: Apply the seed**

MCP `execute_sql` with the file contents. Seed data is not schema, so it is **not** an `apply_migration` — it must stay re-runnable, and every statement above is idempotent via `on conflict do nothing`.

- [ ] **Step 5: Run the test to verify it passes**

Re-run `supabase/tests/0011_seed_test.sql`. Expected: three `PASS` rows.

- [ ] **Step 6: Verify a demo login actually works**

```sql
select case when count(*) = 1 then 'PASS' else 'FAIL: password hash mismatch' end as status
from auth.users
where email = 'aisha.rahman@mypulse360.test'
  and encrypted_password = extensions.crypt('Patient123!', encrypted_password);
```

Expected: `PASS`. This proves the hash is in GoTrue's format, not merely that a row exists.

- [ ] **Step 7: Commit**

```bash
git add supabase/seed.sql supabase/tests/0011_seed_test.sql
git commit -m "feat(db): seed clinics, demo accounts, availability and inventory"
```

---

## Task 11: Security verification — cross-tenant isolation and RPC behaviour

**Files:**
- Create: `supabase/tests/0012_rls_isolation_test.sql`
- Create: `supabase/tests/0013_rpc_behaviour_test.sql`

**Interfaces:**
- Consumes: everything from Tasks 1–10
- Produces: the regression suite re-run after every future migration. No schema changes.

This task is the reason the plan exists. An RLS bug in a health app is a data
breach, so isolation is asserted, not assumed.

- [ ] **Step 1: Write the isolation tests**

Create `supabase/tests/0012_rls_isolation_test.sql`:

```sql
-- Aisha must not see Daniel's medical row.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: patient_profiles leaked ' || count(*) end as status
from public.patient_profiles where id <> '44444444-4444-4444-4444-444444444441';
rollback;

-- Aisha must not see Daniel's appointments.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: appointments leaked ' || count(*) end as status
from public.appointments
where patient_id <> '44444444-4444-4444-4444-444444444441'
  and doctor_id  <> '44444444-4444-4444-4444-444444444441';
rollback;

-- Aisha must not see Daniel's health metrics, goals or chats.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when (select count(*) from public.health_metrics where patient_id <> '44444444-4444-4444-4444-444444444441') = 0
             and (select count(*) from public.wellness_goals where patient_id <> '44444444-4444-4444-4444-444444444441') = 0
             and (select count(*) from public.chat_conversations where patient_id <> '44444444-4444-4444-4444-444444444441') = 0
        then 'PASS' else 'FAIL: patient-owned data leaked' end as status;
rollback;

-- A pharmacist must not read medical history directly.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','33333333-3333-3333-3333-333333333331','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: pharmacist read ' || count(*) || ' patient rows' end as status
from public.patient_profiles;
rollback;

-- A patient must not write appointments directly, bypassing book_appointment.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  insert into public.appointments
    (patient_id, doctor_id, clinic_id, scheduled_at, appointment_type)
  values ('44444444-4444-4444-4444-444444444441','22222222-2222-2222-2222-222222222221',
          '11111111-1111-1111-1111-111111111111', now() + interval '1 day', 'Sneaky');
  raise exception 'FAIL: direct insert succeeded';
exception
  when insufficient_privilege then raise notice 'PASS: direct insert refused';
end;
$$;
rollback;

-- A patient must not be able to promote themselves to doctor. This is the
-- behavioural proof for the column grants added in Task 2 Step 8: without them
-- this UPDATE succeeds and hands the patient staff-level read access.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  update public.profiles set role = 'doctor' where id = auth.uid();
  raise exception 'FAIL: role self-escalation succeeded';
exception
  when insufficient_privilege then raise notice 'PASS: role self-escalation refused';
end;
$$;
rollback;

-- A patient must not be able to move themselves into another clinic.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  update public.profiles set clinic_id = '11111111-1111-1111-1111-111111111112' where id = auth.uid();
  raise exception 'FAIL: clinic self-reassignment succeeded';
exception
  when insufficient_privilege then raise notice 'PASS: clinic self-reassignment refused';
end;
$$;
rollback;

-- Every table in public must have RLS enabled. Catches a table added later
-- without a policy.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: ' || string_agg(relname, ', ') || ' lack RLS' end as status
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
```

- [ ] **Step 2: Run the isolation tests**

Run each block through MCP `execute_sql`. Expected: every `status` reads `PASS`, and the direct-insert block raises the `PASS` notice.

Any `FAIL` is a blocker. Fix the offending policy, re-apply, re-run — do not proceed.

- [ ] **Step 3: Write the RPC behaviour tests**

Create `supabase/tests/0013_rpc_behaviour_test.sql`:

```sql
-- available_slots returns 16 half-hour slots for a Wednesday (09:00-17:00).
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 16 then 'PASS' else 'FAIL: ' || count(*) || ' slots' end as status
from public.available_slots('22222222-2222-2222-2222-222222222221'::uuid, date '2026-08-26');
rollback;

-- Booking the same slot twice: the second attempt is refused.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select public.book_appointment('22222222-2222-2222-2222-222222222221'::uuid,
                               timestamptz '2026-08-26 10:30+00', 'General checkup', null);
do $$
begin
  perform public.book_appointment('22222222-2222-2222-2222-222222222221'::uuid,
                                  timestamptz '2026-08-26 10:30+00', 'General checkup', null);
  raise exception 'FAIL: double booking succeeded';
exception
  when unique_violation then raise notice 'PASS: double booking refused';
end;
$$;
rollback;

-- Approved leave cancels the appointments it collides with.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select public.book_appointment('22222222-2222-2222-2222-222222222221'::uuid,
                               timestamptz '2026-08-27 09:00+00', 'General checkup', null);
set local role postgres;
select set_config('request.jwt.claims',
  json_build_object('sub','22222222-2222-2222-2222-222222222221','role','authenticated')::text, true);
set local role authenticated;
select public.decide_leave(
  (select id from public.apply_leave(date '2026-08-27', date '2026-08-28', 'Conference')),
  'approved');
select case when count(*) = 0 then 'PASS' else 'FAIL: ' || count(*) || ' survived' end as status
from public.appointments
where doctor_id = '22222222-2222-2222-2222-222222222221'
  and scheduled_at::date = date '2026-08-27'
  and status <> 'cancelled';
rollback;

-- FEFO consumes the earliest-expiry batch first.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','33333333-3333-3333-3333-333333333331','role','authenticated')::text, true);
set local role authenticated;
select public.dispense_fefo('55555555-5555-5555-5555-555555555551'::uuid, 10, null);
select case when b.quantity = 110 then 'PASS'
            else 'FAIL: MET-2025-A at ' || b.quantity || ', expected 110' end as status
from public.inventory_batches b
where b.item_id = '55555555-5555-5555-5555-555555555551' and b.batch_number = 'MET-2025-A';
rollback;

-- FEFO refuses when stock is short.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','33333333-3333-3333-3333-333333333331','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  perform public.dispense_fefo('55555555-5555-5555-5555-555555555552'::uuid, 99999, null);
  raise exception 'FAIL: oversized dispense succeeded';
exception
  when check_violation then raise notice 'PASS: insufficient stock refused';
end;
$$;
rollback;
```

- [ ] **Step 4: Run the RPC behaviour tests**

Run each block through MCP `execute_sql`. Expected: every `status` reads `PASS` and both `do` blocks raise their `PASS` notice.

> If the leave test fails on `set local role postgres`, the MCP connection may
> not permit role switching mid-transaction. Split that block into two
> `execute_sql` calls — one per impersonated user — and assert the outcome in
> the second.

- [ ] **Step 5: Final security advisor sweep**

MCP `get_advisors` with `type: "security"`, then `type: "performance"`.
Expected: no ERROR-level security findings. Record any WARN-level findings in
the commit message rather than silently leaving them.

- [ ] **Step 6: Commit**

```bash
git add supabase/tests/0012_rls_isolation_test.sql supabase/tests/0013_rpc_behaviour_test.sql
git commit -m "test(db): assert cross-tenant isolation and RPC invariants"
```

---

## Done criteria

Plan 01 is complete when all of the following hold:

- [ ] 27 tables exist in `public`, every one with RLS enabled
- [ ] `get_advisors(type: "security")` reports no ERROR-level findings
- [ ] All of `supabase/tests/*.sql` report `PASS`
- [ ] Nine migration files are committed under `supabase/migrations/`
- [ ] A demo password verifies against `auth.users.encrypted_password`
- [ ] `flutter analyze` still clean and all 91 Dart tests still pass — **no Dart was touched in this plan**, so any change here is a mistake

## Next plan

Plan 02 — Flutter Supabase client and the auth slice: add `supabase_flutter`,
wire `Env.isMockMode`, implement `SupabaseAuthDataSource`, deploy the
`create-staff-account` Edge Function, and convert the auth providers to
`AsyncValue`.
