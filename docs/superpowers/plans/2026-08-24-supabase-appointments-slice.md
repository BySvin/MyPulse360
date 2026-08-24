# Plan 03 — Appointments and patient profile

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A patient sees their real profile, real availability and real appointments; booking writes to Postgres atomically; the doctor's queue updates live without a refresh.

**Architecture:** `SupabaseAppointmentsDataSource` and `SupabasePatientDataSource` join the existing mocks behind `Env.isMockMode`. Reads become `FutureProvider`, the two genuinely live things become `StreamProvider` on Postgres realtime, and every screen renders `AsyncValue` through one shared widget.

**Tech Stack:** Flutter, Riverpod, `supabase_flutter` 2.17.2, Postgres 17.

**Spec:** `docs/superpowers/specs/2026-08-22-supabase-backend-design.md` (§7 async model, §9 slice 3)

**Predecessors:** Plan 01 (schema) and Plan 02 (auth). Read
`docs/superpowers/plans/2026-08-23-supabase-auth-slice-OUTCOME.md` — its
follow-up list is partly this plan's job.

## Global Constraints

- **Target project:** `arxrtodtnrmhwbecwyxm`. 21 migrations applied. Publishable key ships in the client and is safe; the service-role key never enters the repo.
- **`flutter analyze` clean and 100/100 Dart tests green before every commit.** A broken test is a real signal — investigate, never edit the test to match.
- **The mocks are not deleted.** They remain the test doubles and the `Env.isMockMode` fallback.
- **Enum labels live only in `lib/shared/data/db_enums.dart`.** No Postgres label as an inline string in a datasource.
- **All writes to `appointments` go through the RPCs.** Plan 01 revoked direct INSERT/UPDATE/DELETE from `authenticated`; the collision and leave checks are enforcement, not advice.
- **Every error reaching a user goes through `mapPostgrestError`.** Raw Postgres text leaks table and column names.
- **`execute_sql` returns only the last statement's result when batched.** Run assertions individually.
- **Use Bash for git and flutter.** PowerShell's `git` hangs in this environment.

---

## Why patient profile is in this plan

`book_appointment_page.dart:80` reads `profile?.assignedDoctorId ?? 'user-dr-ahmed'`.
Plan 02's `_ensureLocalPatientProfile` writes a **mock** profile keyed by the
real UUID, with `assignedDoctorId: MockIds.drAhmedUserId` — the literal string
`'user-dr-ahmed'`. Passing that to `available_slots(p_doctor uuid)` raises
`22P02 invalid input syntax for type uuid`.

So booking against Postgres is impossible until the patient profile is
Postgres-backed. The two are one slice, and finishing it lets
`_ensureLocalPatientProfile` be deleted rather than carried further.

---

## File Structure

**Created**

| File | Responsibility |
|------|----------------|
| `supabase/migrations/0022_month_availability.sql` | `month_availability()` — one call per month instead of 31 |
| `supabase/tests/0022_month_availability_test.sql` | Its assertions |
| `lib/shared/data/db_rows.dart` | Row→entity mapping for `Appointment`, `TimeSlot`, `PatientProfile` |
| `lib/shared/presentation/widgets/async_section.dart` | `AsyncSection` — the whole-screen loading/error/data widget spec §7 calls for |
| `lib/features/appointments/data/datasources/supabase_appointments_datasource.dart` | Appointments against Postgres |
| `lib/features/patient/data/datasources/supabase_patient_datasource.dart` | Patient profile against Postgres |
| `test/shared/data/db_rows_test.dart` | Mapping tests |

**Modified**

| File | Change |
|------|--------|
| `lib/features/appointments/domain/repositories/appointments_repository.dart` | reads become `Future`; two become `Stream` |
| `…/data/datasources/appointments_datasource.dart`, `…/repositories/appointments_repository_impl.dart`, `…/mock_appointments_datasource.dart` | match |
| `lib/features/patient/domain/repositories/patient_repository.dart` + its datasource, impl and mock | reads become `Future` |
| `lib/features/appointments/presentation/providers/appointments_providers.dart` | datasource selection, `FutureProvider`/`StreamProvider` |
| `lib/features/patient/presentation/providers/patient_providers.dart` | same |
| `lib/features/doctor/presentation/providers/doctor_providers.dart` | `todaysQueueProvider` becomes a `StreamProvider` |
| 11 appointment consumer files, 14 patient-profile consumer files | render `AsyncValue` |
| `lib/features/auth/presentation/providers/auth_providers.dart` | delete `_ensureLocalPatientProfile` |

---

## Task 1: `month_availability` RPC

**Files:**
- Create: `supabase/migrations/0022_month_availability.sql`
- Create: `supabase/tests/0022_month_availability_test.sql`

**Interfaces:**
- Consumes: `doctor_availability`, `appointments`, `leave_requests`, `staff_unavailability` (Plan 01).
- Produces: `public.month_availability(p_doctor uuid, p_month date)` returning `(day date, open_slots int, is_on_leave boolean)`.

`month_calendar.dart:135` calls `availableSlotsProvider` **once per day cell** —
up to 31 per render, and again on every month navigation. Free against an
in-memory store; 31 network round trips against Postgres. The calendar only
needs two facts per day, so it gets one call that returns them.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0022_month_availability_test.sql`:

```sql
select case when count(*) = 1 then 'PASS' else 'FAIL: month_availability missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'month_availability';

-- It must be SECURITY DEFINER with a pinned search_path, like every other RPC.
select case when count(*) = 1 then 'PASS' else 'FAIL: not definer with pinned search_path' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'month_availability'
  and p.prosecdef and array_to_string(p.proconfig, ',') like '%search_path=public, pg_temp%';

-- anon must not be able to call it.
select case when count(*) = 0 then 'PASS' else 'FAIL: anon can execute month_availability' end as status
from information_schema.role_routine_grants
where routine_schema = 'public' and routine_name = 'month_availability' and grantee = 'anon';

-- A weekday in a seeded month must report open slots for Dr. Rashid.
select case when count(*) >= 20 then 'PASS' else 'FAIL: only ' || count(*) || ' days returned' end as status
from public.month_availability('22222222-2222-2222-2222-222222222221'::uuid, date_trunc('month', current_date + interval '1 month')::date);
```

- [ ] **Step 2: Run each assertion separately and confirm RED**

Expect FAIL on the first three; the fourth will error (function does not exist) rather than return FAIL — **report what you actually see**.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0022_month_availability.sql`:

```sql
-- The booking calendar needs two facts per day: are there any open slots, and
-- is the doctor on leave. Deriving that from available_slots() one day at a
-- time costs 31 round trips per month view. This answers the whole month in
-- one call.
create or replace function public.month_availability(
  p_doctor uuid, p_month date
)
returns table (day date, open_slots int, is_on_leave boolean)
language sql stable security definer set search_path = public, pg_temp as $$
  with days as (
    select generate_series(
             date_trunc('month', p_month)::date,
             (date_trunc('month', p_month) + interval '1 month - 1 day')::date,
             interval '1 day'
           )::date as day
  ),
  leave as (
    select d.day,
           exists (select 1 from public.leave_requests l
                    where l.staff_id = p_doctor and l.status = 'approved'
                      and d.day between l.start_date and l.end_date)
        or exists (select 1 from public.staff_unavailability u
                    where u.staff_id = p_doctor and u.date = d.day) as flag
    from days d
  ),
  slots as (
    select d.day,
           count(*) filter (
             where not exists (
               select 1 from public.appointments ap
               where ap.doctor_id = p_doctor
                 and ap.scheduled_at = s.slot_at
                 and ap.status <> 'cancelled'
             ) and s.slot_at > now()
           )::int as open_slots
    from days d
    join public.doctor_availability a
      on a.doctor_id = p_doctor
     and a.weekday = extract(isodow from d.day)::smallint - 1
    cross join lateral (
      select generate_series(
               (d.day + a.start_time) at time zone 'UTC',
               (d.day + a.end_time) at time zone 'UTC' - make_interval(mins => a.slot_minutes),
               make_interval(mins => a.slot_minutes)
             ) as slot_at
    ) s
    group by d.day
  )
  select d.day,
         coalesce(sl.open_slots, 0) as open_slots,
         l.flag as is_on_leave
  from days d
  left join slots sl on sl.day = d.day
  join leave l on l.day = d.day
  order by d.day
$$;

revoke all on function public.month_availability(uuid, date) from public, anon;
grant execute on function public.month_availability(uuid, date) to authenticated;
```

> **UTC anchoring is deliberate**, matching `available_slots`. `d.day + a.start_time`
> is a timestamp *without* zone; left implicit its cast depends on the
> connection's TimeZone and two clients in different zones would see different
> availability.

- [ ] **Step 4: Apply the migration**

`apply_migration`, `name: "month_availability"`, `project_id: "arxrtodtnrmhwbecwyxm"`.

- [ ] **Step 5: Re-run each assertion — expect four PASS**

Then run it for a real month and eyeball the shape:

```sql
select * from public.month_availability(
  '22222222-2222-2222-2222-222222222221'::uuid,
  date_trunc('month', current_date + interval '1 month')::date
) order by day limit 10;
```

Expect weekdays with `open_slots = 16` and weekends with `0`. **Report the
actual numbers** — if weekends show slots, the weekday mapping is wrong.

- [ ] **Step 6: Security advisors**

`get_advisors` `type: "security"` — no ERROR-level findings.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0022_month_availability.sql supabase/tests/0022_month_availability_test.sql
git commit -m "feat(db): add month_availability so the calendar costs one call"
```

---

## Task 2: Row mapping

**Files:**
- Create: `lib/shared/data/db_rows.dart`
- Test: `test/shared/data/db_rows_test.dart`
- Modify: `lib/shared/data/db_enums.dart`

**Interfaces:**
- Produces: `appointmentFromRow(Map<String, dynamic>) → Appointment`, `timeSlotFromRow(...) → TimeSlot`, `patientProfileFromRow(...) → PatientProfile`, and `appointmentStatusFromDb`/`appointmentStatusToDb`.

Pure functions, no I/O — the only genuinely unit-testable part of this slice,
and doing it first keeps the datasources free of field-name literals.

- [ ] **Step 1: Add the appointment status mapping**

Append to `lib/shared/data/db_enums.dart`:

```dart
const _appointmentStatusToDb = <AppointmentStatus, String>{
  AppointmentStatus.scheduled: 'scheduled',
  AppointmentStatus.confirmed: 'confirmed',
  AppointmentStatus.inProgress: 'in_progress',
  AppointmentStatus.completed: 'completed',
  AppointmentStatus.cancelled: 'cancelled',
  AppointmentStatus.rescheduled: 'rescheduled',
};

String appointmentStatusToDb(AppointmentStatus s) => _appointmentStatusToDb[s]!;

AppointmentStatus appointmentStatusFromDb(String label) {
  for (final e in _appointmentStatusToDb.entries) {
    if (e.value == label) return e.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown appointment_status from the database');
}
```

Wellness goals need two more, used by Task 7:

```dart
const _wellnessGoalTypeToDb = <WellnessGoalType, String>{
  WellnessGoalType.exercise: 'exercise',
  WellnessGoalType.hydration: 'hydration',
  WellnessGoalType.sleep: 'sleep',
  WellnessGoalType.diet: 'diet',
  WellnessGoalType.custom: 'custom',
};

String wellnessGoalTypeToDb(WellnessGoalType t) => _wellnessGoalTypeToDb[t]!;

WellnessGoalType wellnessGoalTypeFromDb(String label) {
  for (final e in _wellnessGoalTypeToDb.entries) {
    if (e.value == label) return e.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown wellness_goal_type from the database');
}

const _goalStatusToDb = <GoalStatus, String>{
  GoalStatus.onTrack: 'on_track',
  GoalStatus.atRisk: 'at_risk',
  GoalStatus.excellent: 'excellent',
  GoalStatus.behind: 'behind',
};

String goalStatusToDb(GoalStatus s) => _goalStatusToDb[s]!;

GoalStatus goalStatusFromDb(String label) {
  for (final e in _goalStatusToDb.entries) {
    if (e.value == label) return e.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown goal_status from the database');
}
```

Add the imports for `AppointmentStatus`, `WellnessGoalType` and `GoalStatus`.
**Verify all three Dart enums match these maps exactly** — read
`lib/features/appointments/domain/entities/appointment.dart` and
`lib/features/patient/domain/entities/wellness_goal.dart`, and report if any
value is missing or spelled differently. Do not guess: Plan 01 found two enums
whose values did not match the obvious assumption.

- [ ] **Step 2: Write the failing tests**

Create `test/shared/data/db_rows_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
import 'package:mypulse360/shared/data/db_enums.dart';
import 'package:mypulse360/shared/data/db_rows.dart';

void main() {
  group('appointmentStatus mapping', () {
    test('round-trips every value', () {
      for (final s in AppointmentStatus.values) {
        expect(appointmentStatusFromDb(appointmentStatusToDb(s)), s);
      }
    });

    test('spells the multi-word label snake_case', () {
      expect(appointmentStatusToDb(AppointmentStatus.inProgress), 'in_progress');
    });

    test('throws on an unknown label rather than guessing', () {
      expect(() => appointmentStatusFromDb('no_show'), throwsArgumentError);
    });
  });

  group('appointmentFromRow', () {
    test('maps a row and parses the timestamp as UTC', () {
      final a = appointmentFromRow({
        'id': 'a1',
        'patient_id': 'p1',
        'doctor_id': 'd1',
        'clinic_id': 'c1',
        'scheduled_at': '2026-09-02T09:00:00+00:00',
        'duration_minutes': 30,
        'appointment_type': 'General checkup',
        'status': 'scheduled',
        'reason_for_visit': null,
        'room_label': null,
      });

      expect(a.id, 'a1');
      expect(a.status, AppointmentStatus.scheduled);
      expect(a.scheduledAt.isUtc, isTrue);
      expect(a.scheduledAt.hour, 9);
      expect(a.reasonForVisit, isNull);
    });
  });

  group('timeSlotFromRow', () {
    test('a booked slot is also disabled', () {
      final s = timeSlotFromRow({
        'slot_at': '2026-09-02T10:30:00+00:00',
        'is_booked': true,
        'is_doctor_on_leave': false,
        'is_past': false,
      });
      expect(s.isBooked, isTrue);
      expect(s.isDisabled, isTrue);
    });

    test('a free future slot is selectable', () {
      final s = timeSlotFromRow({
        'slot_at': '2026-09-02T11:00:00+00:00',
        'is_booked': false,
        'is_doctor_on_leave': false,
        'is_past': false,
      });
      expect(s.isDisabled, isFalse);
    });

    test('leave disables the slot even when nothing is booked', () {
      final s = timeSlotFromRow({
        'slot_at': '2026-09-02T11:00:00+00:00',
        'is_booked': false,
        'is_doctor_on_leave': true,
        'is_past': false,
      });
      expect(s.isDisabled, isTrue);
    });
  });
}
```

- [ ] **Step 3: Run and confirm RED**

`flutter test test/shared/data/db_rows_test.dart` — compilation failure, `db_rows.dart` does not exist.

- [ ] **Step 4: Write the mapping**

Create `lib/shared/data/db_rows.dart`:

```dart
import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/appointments/domain/entities/time_slot.dart';
import '../../features/patient/domain/entities/patient_profile.dart';
import '../../features/patient/domain/entities/wellness_goal.dart';
import 'db_enums.dart';

/// Postgres row → domain entity. Field names appear here and nowhere else, so
/// a column rename fails in one file rather than at three call sites.

DateTime _utc(Object? v) => DateTime.parse(v! as String).toUtc();

Appointment appointmentFromRow(Map<String, dynamic> r) => Appointment(
      id: r['id'] as String,
      patientId: r['patient_id'] as String,
      doctorId: r['doctor_id'] as String,
      clinicId: r['clinic_id'] as String,
      scheduledAt: _utc(r['scheduled_at']),
      durationMinutes: r['duration_minutes'] as int,
      appointmentType: r['appointment_type'] as String,
      status: appointmentStatusFromDb(r['status'] as String),
      reasonForVisit: r['reason_for_visit'] as String?,
      roomLabel: r['room_label'] as String?,
    );

/// `available_slots` already computes booked / on-leave / past server-side.
/// `isDisabled` is the union of those three: the UI only needs to know whether
/// the slot can be tapped, and deriving it here keeps that rule in one place.
/// `isSelected` is deliberately not set: it is UI state the booking page owns
/// via `copyWith`, not something the database knows. Confirm `TimeSlot`'s
/// constructor defaults it to `false` before relying on that — if it is
/// required, report rather than inventing a value.
TimeSlot timeSlotFromRow(Map<String, dynamic> r) {
  final booked = r['is_booked'] as bool;
  final onLeave = r['is_doctor_on_leave'] as bool;
  final past = r['is_past'] as bool;
  return TimeSlot(
    dateTime: _utc(r['slot_at']),
    isBooked: booked,
    isDoctorOnLeave: onLeave,
    isDisabled: booked || onLeave || past,
  );
}

List<String> _textArray(Object? v) =>
    (v as List?)?.map((e) => e as String).toList() ?? const [];

PatientProfile patientProfileFromRow(Map<String, dynamic> r) => PatientProfile(
      id: r['id'] as String,
      dateOfBirth: r['date_of_birth'] == null ? null : DateTime.parse(r['date_of_birth'] as String),
      gender: r['gender'] as String?,
      bloodType: r['blood_type'] as String?,
      heightCm: (r['height_cm'] as num).toDouble(),
      weightKg: (r['weight_kg'] as num).toDouble(),
      allergies: _textArray(r['allergies']),
      chronicConditions: _textArray(r['chronic_conditions']),
      currentMedications: _textArray(r['current_medications']),
      assignedDoctorId: r['assigned_doctor_id'] as String? ?? '',
      insuranceProvider: r['insurance_provider'] as String?,
      emergencyContactName: r['emergency_contact_name'] as String?,
      emergencyContactPhone: r['emergency_contact_phone'] as String?,
      preferredClinicId: r['preferred_clinic_id'] as String?,
      preferredLanguage: r['preferred_language'] as String?,
      notifyAppointments: r['notify_appointments'] as bool,
      notifyPrescriptions: r['notify_prescriptions'] as bool,
      notifyHealthTips: r['notify_health_tips'] as bool,
    );

WellnessGoal wellnessGoalFromRow(Map<String, dynamic> r) => WellnessGoal(
      id: r['id'] as String,
      patientId: r['patient_id'] as String,
      type: wellnessGoalTypeFromDb(r['type'] as String),
      name: r['name'] as String,
      targetValue: (r['target_value'] as num).toDouble(),
      currentValue: (r['current_value'] as num).toDouble(),
      unit: r['unit'] as String,
      status: goalStatusFromDb(r['status'] as String),
      targetDate: DateTime.parse(r['target_date'] as String),
    );
```

> **Check `PatientProfile`'s constructor before writing this** — read
> `lib/features/patient/domain/entities/patient_profile.dart` and confirm every
> named parameter above exists with that name and nullability. If
> `assignedDoctorId` is non-nullable and the column can be null, the `?? ''`
> above is a placeholder that will read oddly in the UI — **report that** rather
> than inventing a different default.

- [ ] **Step 5: Run and confirm GREEN, then the full suite**

```bash
flutter test test/shared/data/db_rows_test.dart
flutter analyze
flutter test
```

Expect the new tests passing and the suite at 100 + however many you added.
**Report the actual total.**

- [ ] **Step 6: Commit**

```bash
git add lib/shared/data test/shared/data
git commit -m "feat(data): map appointment, slot and patient rows to entities"
```

---

## Task 3: Async interfaces for appointments and patient

**Files:**
- Modify: `lib/features/appointments/domain/repositories/appointments_repository.dart`
- Modify: `lib/features/appointments/data/datasources/appointments_datasource.dart`
- Modify: `lib/features/appointments/data/repositories/appointments_repository_impl.dart`
- Modify: `lib/features/appointments/data/datasources/mock_appointments_datasource.dart`
- Modify: the same four files for `patient`
- Modify: `test/` wherever the compiler points

**Interfaces:**
- Produces: `Future<List<Appointment>> getForPatient(String)`, `Future<List<Appointment>> getForDoctor(String)`, `Future<List<TimeSlot>> getAvailableSlots({...})`, `Future<List<({DateTime day, int openSlots, bool isOnLeave})>> getMonthAvailability({required String doctorId, required DateTime month})`, `Stream<Appointment?> watchNextUpcoming(String patientId)`, `Stream<List<Appointment>> watchTodaysQueue(String doctorId)`; and on patient, `Future<PatientProfile?> getProfile(String)`, `Future<List<WellnessGoal>> getWellnessGoals(String)`.

`getNextUpcoming` becomes a **Stream** and is renamed `watchNextUpcoming`;
`todaysQueue` likewise. Those are the only two things in the product that are
genuinely live (spec §7).

This task deliberately breaks the build. **Do not commit it alone** — Task 4
repairs it and they commit together.

- [ ] **Step 1: Change the appointment interfaces**

In `appointments_repository.dart` and `appointments_datasource.dart`:

```dart
  Future<List<Appointment>> getForPatient(String patientId);

  Future<List<Appointment>> getForDoctor(String doctorId);

  /// Live: the dashboard banner re-renders when this patient books, cancels or
  /// is bumped by an approved leave.
  Stream<Appointment?> watchNextUpcoming(String patientId);

  /// Live: the doctor's queue re-orders as patients book and are seen.
  Stream<List<Appointment>> watchTodaysQueue(String doctorId);

  Future<List<TimeSlot>> getAvailableSlots({required String doctorId, required DateTime date});

  /// One call per calendar month. Per-day slot queries cost 31 round trips.
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>> getMonthAvailability({
    required String doctorId,
    required DateTime month,
  });
```

Keep `book`, `updateStatus` and `reschedule` as they are — already `Future`.

- [ ] **Step 2: Change the patient interfaces**

`getProfile` and `getWellnessGoals` become `Future`. Leave the write methods alone.

- [ ] **Step 3: Update both repository impls** to match — they delegate, so the change is mechanical.

- [ ] **Step 4: Update both mocks**

Add `async` and return the same values. For the two streams, the mock emits once and then whenever the revision changes is not available to it — so emit a single value:

```dart
  @override
  Stream<Appointment?> watchNextUpcoming(String patientId) =>
      Stream.value(_nextUpcoming(patientId));

  @override
  Stream<List<Appointment>> watchTodaysQueue(String doctorId) =>
      Stream.value(_todaysQueue(doctorId));
```

Move the existing bodies into the private helpers. `getMonthAvailability` on the
mock derives from the existing per-day logic:

```dart
  @override
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>> getMonthAvailability({
    required String doctorId,
    required DateTime month,
  }) async {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    return [
      for (var i = 0; i < days; i++)
        () {
          final day = DateTime(first.year, first.month, i + 1);
          final slots = getAvailableSlotsSync(doctorId: doctorId, date: day);
          return (
            day: day,
            openSlots: slots.where((s) => !s.isDisabled).length,
            isOnLeave: slots.any((s) => s.isDoctorOnLeave),
          );
        }(),
    ];
  }
```

Rename the mock's existing synchronous slot method to `getAvailableSlotsSync`
(private to the mock) and have the async `getAvailableSlots` delegate to it, so
both paths share one implementation.

- [ ] **Step 5: Record the breakage**

```bash
flutter analyze
```

Record the full error list. It should be confined to the 11 appointment
consumer files, the 14 patient-profile consumer files, `doctor_providers.dart`,
`pharmacist_providers.dart`, `scheduling_providers.dart`, and the two provider
files. **If an error appears anywhere else, stop and report** — a call site
neither of us accounted for.

Do not commit. Continue to Task 4.

---

## Task 4: Convert the consumers

**Files:**
- Create: `lib/shared/presentation/widgets/async_section.dart`
- Modify: `lib/features/appointments/presentation/providers/appointments_providers.dart`
- Modify: `lib/features/patient/presentation/providers/patient_providers.dart`
- Modify: `lib/features/doctor/presentation/providers/doctor_providers.dart`
- Modify: the consumer files the compiler listed in Task 3 Step 5

**Interfaces:**
- Produces: `AsyncSection` widget; `patientAppointmentsProvider` etc. as `FutureProvider.family`; `nextUpcomingAppointmentProvider` and `todaysQueueProvider` as `StreamProvider.family`.

One batched pass. Same shape repeated — do it as a single sweep, not file by file.

- [ ] **Step 1: Write the shared async widget**

Create `lib/shared/presentation/widgets/async_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_theme.dart';

/// The three states of a screen region backed by the network.
///
/// Whole-screen content renders through this rather than `valueOrNull`,
/// because an empty list drawn during a load reads as "you have no
/// appointments" — a lie the user acts on.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return value.when(
      data: data,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.textTertiary, size: 32),
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
```

> `'$error'` is safe here: every error from the data layer is a `DbFailure`,
> whose `toString()` returns its human-readable message and never the Postgres
> cause. If a raw exception ever reaches this widget that is a bug in the
> datasource, not here.

- [ ] **Step 2: Convert the appointment providers**

```dart
final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  final AppointmentsDataSource dataSource = Env.isMockMode
      ? MockAppointmentsDataSource(ref.watch(mockDatabaseProvider))
      : SupabaseAppointmentsDataSource(ref.watch(supabaseClientProvider));
  return AppointmentsRepositoryImpl(dataSource);
});

/// Kept, not deleted.
///
/// Spec §7 calls for removing this once realtime replaces it, but scheduling
/// and pharmacist providers still watch it and are still mock-backed. Deleting
/// it now breaks their refresh. It goes in the cutover slice, when nothing
/// mock-backed is left to need it.
final appointmentsRevisionProvider = StateProvider<int>((ref) => 0);

final patientAppointmentsProvider =
    FutureProvider.family<List<Appointment>, String>((ref, patientId) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).getForPatient(patientId);
});

final doctorAppointmentsProvider =
    FutureProvider.family<List<Appointment>, String>((ref, doctorId) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).getForDoctor(doctorId);
});

final nextUpcomingAppointmentProvider =
    StreamProvider.family<Appointment?, String>((ref, patientId) {
  return ref.watch(appointmentsRepositoryProvider).watchNextUpcoming(patientId);
});

final availableSlotsProvider =
    FutureProvider.family<List<TimeSlot>, ({String doctorId, DateTime date})>((ref, args) {
  ref.watch(appointmentsRevisionProvider);
  return ref
      .watch(appointmentsRepositoryProvider)
      .getAvailableSlots(doctorId: args.doctorId, date: args.date);
});

final monthAvailabilityProvider = FutureProvider.family<
    List<({DateTime day, int openSlots, bool isOnLeave})>,
    ({String doctorId, DateTime month})>((ref, args) {
  ref.watch(appointmentsRevisionProvider);
  return ref
      .watch(appointmentsRepositoryProvider)
      .getMonthAvailability(doctorId: args.doctorId, month: args.month);
});
```

- [ ] **Step 3: Convert `todaysQueueProvider`**

In `doctor_providers.dart`:

```dart
final todaysQueueProvider = StreamProvider.family<List<Appointment>, String>((ref, doctorId) {
  return ref.watch(appointmentsRepositoryProvider).watchTodaysQueue(doctorId);
});
```

- [ ] **Step 4: Convert the patient providers** the same way — `patientProfileProvider` and `wellnessGoalsProvider` become `FutureProvider.family`.

`onboardingCompleteProvider` currently returns `bool`. Make it:

```dart
final onboardingCompleteProvider = Provider.family<bool, String>((ref, patientId) {
  // A profile that has not loaded yet is not "not onboarded" — treating it as
  // false is what pinned real patients to the welcome screen in Plan 02.
  return ref.watch(patientProfileProvider(patientId)).valueOrNull != null;
});
```

> **This is load-bearing.** The router reads it. While the profile is loading,
> `valueOrNull` is null and the gate would bounce a real patient to onboarding —
> exactly the Plan 02 Critical. Task 6 must make the router tolerate a loading
> profile; see its Step 4.

- [ ] **Step 5: Rewrite `month_calendar.dart` to one call**

Replace the per-day `availableSlotsProvider` watch at line 135 with a single
month watch in `build`, and look each day up from it:

```dart
    final month = ref.watch(monthAvailabilityProvider(
      (doctorId: widget.doctorId, month: _displayedMonth),
    ));
```

then in `_buildDayCell`, take the record for that day from the resolved list
(passing it down as a parameter rather than re-watching). While the month is
loading, render every cell as neither open nor on-leave and disable taps.

- [ ] **Step 6: Convert the remaining consumers**

Whole-screen content (`appointments_list_page`, `queue_number_page`,
`doctor_dashboard_page`'s queue, `patient_history_page`) renders through
`AsyncSection`. Values that decorate other content may use `.valueOrNull` with
the existing null fallback — the same rule Plan 02 used.

- [ ] **Step 7: Verify**

```bash
flutter analyze
flutter test
```

No issues; suite at its Task 2 total. Fix any test that breaks by understanding
it first — **report, do not silence**.

- [ ] **Step 8: Commit Tasks 3 and 4 together**

```bash
git add lib test
git commit -m "refactor(appointments): make reads async and the queue live"
```

---

## Task 5: SupabaseAppointmentsDataSource — reads

**Files:**
- Create: `lib/features/appointments/data/datasources/supabase_appointments_datasource.dart`

**Interfaces:**
- Consumes: `supabaseClientProvider`, `db_rows.dart`, `db_failure.dart`, the async `AppointmentsDataSource`.
- Produces: the reads and both streams. Writes are Task 6 and stay `UnimplementedError` here.

- [ ] **Step 1: Write the reads**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_enums.dart';
import '../../../../shared/data/db_failure.dart';
import '../../../../shared/data/db_rows.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import 'appointments_datasource.dart';

// `appointment.dart` carries both Appointment and AppointmentStatus; the
// streams below filter on the latter.

class SupabaseAppointmentsDataSource implements AppointmentsDataSource {
  SupabaseAppointmentsDataSource(this._client);

  final SupabaseClient _client;

  static const _cols =
      'id, patient_id, doctor_id, clinic_id, scheduled_at, duration_minutes, '
      'appointment_type, status, reason_for_visit, room_label';

  @override
  Future<List<Appointment>> getForPatient(String patientId) async {
    try {
      final rows = await _client
          .from('appointments')
          .select(_cols)
          .eq('patient_id', patientId)
          .order('scheduled_at', ascending: false);
      return rows.map(appointmentFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<Appointment>> getForDoctor(String doctorId) async {
    try {
      final rows = await _client
          .from('appointments')
          .select(_cols)
          .eq('doctor_id', doctorId)
          .order('scheduled_at');
      return rows.map(appointmentFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final rows = await _client.rpc('available_slots', params: {
        'p_doctor': doctorId,
        'p_date': _dateOnly(date),
      });
      return (rows as List).map((r) => timeSlotFromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>> getMonthAvailability({
    required String doctorId,
    required DateTime month,
  }) async {
    try {
      final rows = await _client.rpc('month_availability', params: {
        'p_doctor': doctorId,
        'p_month': _dateOnly(DateTime(month.year, month.month, 1)),
      });
      return (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        return (
          day: DateTime.parse(m['day'] as String),
          openSlots: m['open_slots'] as int,
          isOnLeave: m['is_on_leave'] as bool,
        );
      }).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// Postgres `date` wants a bare calendar day. Sending a full timestamp makes
  /// the server reinterpret it in its own zone and silently answer for the
  /// wrong day near midnight.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Realtime on `appointments`, filtered to this patient. `stream` needs the
  /// table's primary key to diff rows.
  @override
  Stream<Appointment?> watchNextUpcoming(String patientId) {
    final now = DateTime.now().toUtc();
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((rows) {
          final upcoming = rows
              .map((r) => appointmentFromRow(Map<String, dynamic>.from(r)))
              .where((a) =>
                  a.status != AppointmentStatus.cancelled &&
                  a.scheduledAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return upcoming.isEmpty ? null : upcoming.first;
        });
  }

  @override
  Stream<List<Appointment>> watchTodaysQueue(String doctorId) {
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .map((rows) {
          final today = DateTime.now().toUtc();
          return rows
              .map((r) => appointmentFromRow(Map<String, dynamic>.from(r)))
              .where((a) =>
                  a.status != AppointmentStatus.cancelled &&
                  a.scheduledAt.year == today.year &&
                  a.scheduledAt.month == today.month &&
                  a.scheduledAt.day == today.day)
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        });
  }

  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) async =>
      throw UnimplementedError('Booking lands in Task 6');

  @override
  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status) async =>
      throw UnimplementedError('Status changes land in Task 6');

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) async =>
      throw UnimplementedError('Rescheduling lands in Task 6');
}
```

> **`.stream()` filtering is client-side for the `where` clauses above.** Supabase
> realtime supports `.eq` on the stream builder but not arbitrary predicates, so
> the date and status filters run in Dart on each emission. That is correct but
> means every row for that doctor arrives. Acceptable at clinic scale; note it.

- [ ] **Step 2: Verify realtime is enabled for the table**

Realtime must be enabled on `public.appointments` or both streams emit only the
initial snapshot and never update. Check:

```sql
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and tablename = 'appointments';
```

**If it returns no rows, realtime is off.** Enable it with a migration
`supabase/migrations/0023_realtime_appointments.sql`:

```sql
alter publication supabase_realtime add table public.appointments;
```

Apply as `name: "realtime_appointments"`, and re-run the check. **Report which
case you hit** — this is the single most likely reason the live queue silently
does nothing.

- [ ] **Step 3: Verify**

`flutter analyze` clean, suite green. Report what you could not verify — the
streams cannot be exercised without a running app and the controller does that.

- [ ] **Step 4: Commit**

```bash
git add lib supabase
git commit -m "feat(appointments): read appointments and availability from Postgres"
```

---

## Task 6: Booking, rescheduling and the taken-slot path

**Files:**
- Modify: `lib/features/appointments/data/datasources/supabase_appointments_datasource.dart`
- Modify: `lib/features/appointments/presentation/pages/book_appointment_page.dart`
- Modify: `lib/config/router/app_router.dart`

**Interfaces:**
- Consumes: `book_appointment`, `reschedule_appointment`, `set_appointment_status` RPCs (Plan 01).

- [ ] **Step 1: Implement the three writes**

```dart
  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) async {
    try {
      // patientId is ignored deliberately: book_appointment derives the patient
      // from auth.uid() so a client cannot book on someone else's behalf.
      final row = await _client.rpc('book_appointment', params: {
        'p_doctor': doctorId,
        'p_at': scheduledAt.toUtc().toIso8601String(),
        'p_type': appointmentType,
        'p_reason': reasonForVisit,
      });
      return appointmentFromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) async {
    try {
      final row = await _client.rpc('reschedule_appointment', params: {
        'p_appointment': appointmentId,
        'p_new_at': newTime.toUtc().toIso8601String(),
      });
      return appointmentFromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status) async {
    try {
      final row = await _client.rpc('set_appointment_status', params: {
        'p_appointment': appointmentId,
        'p_status': appointmentStatusToDb(status),
      });
      return appointmentFromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
```

- [ ] **Step 2: Handle the taken slot in the UI**

`book_appointment_page.dart`'s `_book` currently pops on completion regardless.
`mapPostgrestError` turns `23505` into "That time slot was just taken. Please
pick another." — which must be shown, and the grid refreshed:

```dart
    setState(() => _booking = true);
    try {
      await ref.read(appointmentsRepositoryProvider).book(
            patientId: patientId,
            doctorId: doctorId,
            scheduledAt: slot.dateTime,
            appointmentType: _isCustom ? customText : _type,
            reasonForVisit: _isCustom ? customText : null,
          );
      ref.read(appointmentsRevisionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // Someone booked this slot between the grid rendering and Confirm.
      // Refresh so the grid shows the truth, and clear the stale selection.
      ref.read(appointmentsRevisionProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        _booking = false;
        _selectedSlot = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
```

- [ ] **Step 3: Route booking through the patient's real doctor**

`book_appointment_page.dart:80` reads `profile?.assignedDoctorId ?? 'user-dr-ahmed'`.
After Task 7 the profile is Postgres-backed, so the fallback is what breaks
things — a mock id sent to a `uuid` parameter. Remove it:

```dart
    final profileAsync = ref.watch(patientProfileProvider(user.id));
    final doctorId = profileAsync.valueOrNull?.assignedDoctorId;
    if (doctorId == null || doctorId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No doctor is assigned to your account yet. Contact the clinic.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
```

An unassigned patient gets a sentence they can act on, instead of a `22P02`.

- [ ] **Step 4: Make the router tolerate a loading profile**

`onboardingCompleteProvider` now reads an `AsyncValue`. While it loads,
`valueOrNull` is null and the router's `!onboarded` branch would bounce a real
patient to onboarding — the Plan 02 Critical, returning by a different route.

In `app_router.dart`, gate on the loading state explicitly:

```dart
      final profile = ref.watch(patientProfileProvider(user.id));
      if (user.role == UserRole.patient && profile.isLoading) {
        // Don't decide the onboarding question until the answer has arrived.
        return null;
      }
```

placed immediately before the existing `onboarded` computation, and change that
computation to use `profile.valueOrNull != null`.

> `redirect` uses `ref.read` elsewhere in this file. Use `ref.read` here too and
> rely on `_RouterRefreshNotifier` for re-evaluation — a `ref.watch` inside
> `redirect` is not supported.

- [ ] **Step 5: Verify**

`flutter analyze` clean, suite green. Report what you could not verify.

- [ ] **Step 6: Commit**

```bash
git add lib
git commit -m "feat(appointments): book and reschedule through the RPCs"
```

---

## Task 7: SupabasePatientDataSource

**Files:**
- Create: `lib/features/patient/data/datasources/supabase_patient_datasource.dart`
- Modify: `lib/features/patient/presentation/providers/patient_providers.dart`
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart`

**Interfaces:**
- Produces: patient profile reads and updates against Postgres; removal of `_ensureLocalPatientProfile`.

- [ ] **Step 1: Read the existing interface**

Read `lib/features/patient/domain/repositories/patient_repository.dart` in full
and implement **every** method. `createInitialProfile` is now handled by
`register_patient()` at sign-up, so it should throw
`UnimplementedError('Profiles are created by register_patient at sign-up')`
rather than duplicating that write — **report if some other caller still needs it.**

- [ ] **Step 2: Write the datasource**

Selects use the column list matching `patientProfileFromRow`. Updates go through
`.update({...}).eq('id', patientId)` — Plan 01's column grants allow the
medical and preference fields and exclude `assigned_doctor_id`, so an attempt to
write that column will be refused. **Do not add it to any update payload.**

Wellness goals read from `wellness_goals`, mapped with `wellnessGoalFromRow`
(already written in Task 2). Select
`id, patient_id, type, name, target_value, current_value, unit, status, target_date`
and order by `target_date`.

- [ ] **Step 3: Select the datasource by mode**

```dart
final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final PatientDataSource dataSource = Env.isMockMode
      ? MockPatientDataSource(ref.watch(mockDatabaseProvider))
      : SupabasePatientDataSource(ref.watch(supabaseClientProvider));
  return PatientRepositoryImpl(dataSource);
});
```

- [ ] **Step 4: Delete the Plan 02 bridge**

Remove `_ensureLocalPatientProfile` from `AuthController` and its three call
sites. It existed only because the patient profile lived in the mock while the
user id came from Supabase; that mismatch is now gone.

**Verify the onboarding gate still clears** — `register_patient` creates the
`patient_profiles` row at sign-up, so `patientProfileProvider` finds it. If it
does not, stop and report rather than reinstating the bridge.

- [ ] **Step 5: Verify**

`flutter analyze` clean, suite green.

- [ ] **Step 6: Commit**

```bash
git add lib
git commit -m "feat(patient): read and update the profile from Postgres"
```

---

## Task 8: End-to-end verification

**Files:**
- Create: `docs/superpowers/plans/2026-08-24-supabase-appointments-slice-OUTCOME.md`

No code. Verification is the controller's — subagents cannot drive a browser.

- [ ] **Step 1: The matrix**

Record what actually happened for each, not what should have.

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Patient opens Book Appointment | Calendar renders; **one** `month_availability` request, not 31 |
| 2 | Patient picks a weekday | 16 slots; booked ones struck through |
| 3 | Patient books a free slot | Appointment appears in their list |
| 4 | Same slot booked twice | "That time slot was just taken", grid refreshes, selection cleared |
| 5 | Doctor's queue on web | Shows the booking without a manual refresh |
| 6 | Patient reschedules | Old slot frees, new slot taken |
| 7 | Patient cancels | Status cancelled; slot reopens |
| 8 | Doctor approves leave covering a booking | Appointment cancelled; patient's list reflects it |
| 9 | Patient with no assigned doctor | The sentence from Task 6 Step 3, not a crash |
| 10 | Reload mid-session | Profile and appointments return; no onboarding bounce |
| 11 | `--dart-define=MYPULSE_MOCK=true` | Whole app runs offline |

For #1, count requests in the browser network panel — that is the whole point
of Task 1.

- [ ] **Step 2: Confirm nothing regressed**

`flutter analyze`, `flutter test`, and re-run Plan 01's
`0015_rls_isolation_test.sql` and `0016_rpc_behaviour_test.sql` block by block.

- [ ] **Step 3: Write the outcome doc and commit**

---

## Done criteria

- [ ] All 11 matrix rows verified with recorded results
- [ ] The calendar issues one request per month, not 31
- [ ] The doctor's queue updates without a refresh
- [ ] A concurrent booking shows the taken-slot message rather than failing silently
- [ ] `_ensureLocalPatientProfile` is deleted
- [ ] `flutter analyze` clean; Dart suite green
- [ ] Plan 01's isolation and RPC suites still pass

## Next plan

Plan 04 — prescriptions and consultations, then health metrics, pharmacy,
scheduling, chat, and the cutover that deletes `appointmentsRevisionProvider`
and flips `Env.isMockMode`'s remaining consumers.
