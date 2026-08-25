# Plan 02 — Supabase client and the auth slice

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make login, sign-up, session restore, forced password change and staff provisioning run against the real Supabase project instead of the in-memory mock.

**Architecture:** The repository interfaces become fully async, a `SupabaseAuthDataSource` joins the existing `MockAuthDataSource` behind `Env.isMockMode`, and Supabase's own persisted session replaces the Hive-stored user id. The 16 synchronous `getUserById` call sites move to a `FutureProvider.family` so no widget reads a network value synchronously.

**Tech Stack:** Flutter, Riverpod, `supabase_flutter`, Postgres 17, Supabase Edge Functions (Deno/TypeScript).

**Spec:** `docs/superpowers/specs/2026-08-22-supabase-backend-design.md` (§3 architecture, §6 Edge Function, §7 async model, §9 slice 2)

**Predecessor:** `docs/superpowers/plans/2026-08-22-supabase-database-foundation.md` and its outcome doc. Plan 01 built the schema; this plan is the first to touch Dart.

## Global Constraints

- **Target project:** `arxrtodtnrmhwbecwyxm`, URL `https://arxrtodtnrmhwbecwyxm.supabase.co`, region `ap-northeast-1`, Postgres 17.6.
- **The publishable key ships in the client and is safe to commit.** It is safe *because* RLS stands between it and the data. The service-role key exists only in the Edge Function environment and must never enter the repo.
- **The 91 existing Dart tests must stay green throughout.** They exercise domain usecases against the mock datasources. A test that breaks signals an accidental domain change — investigate, do not update the test to match.
- **`flutter analyze` must report no issues before every commit.**
- **The mock is not deleted.** It stays as the test double and as the `Env.isMockMode` fallback.
- **Enum labels are snake_case in Postgres, lowerCamelCase in Dart.** Mapping lives in exactly one place per enum (Task 3), never inline in a datasource.
- **No secrets in the repo.** The service-role key is set via `supabase secrets set` / the dashboard only.
- **Use Bash for git and file work.** PowerShell's `git` invocation hangs in this environment.
- **`execute_sql` returns only the last statement's result when batched.** Run assertions individually.

---

## File Structure

**Created**

| File | Responsibility |
|------|----------------|
| `supabase/config.toml` | Lets the Supabase CLI run at all (`start`, `db reset`, `functions deploy`) |
| `supabase/migrations/0016_plan02_prep.sql` | The deferred follow-ups Plan 01 surfaced, plus `assign_default_doctor` |
| `supabase/tests/0017_plan02_prep_test.sql` | Assertions for the above |
| `supabase/functions/create-staff-account/index.ts` | The one server-side function; holds the service-role key |
| `lib/config/env/supabase_config.dart` | Project URL + publishable key, and nothing else |
| `lib/shared/data/supabase_providers.dart` | `supabaseClientProvider` — the single `SupabaseClient` accessor |
| `lib/shared/data/db_enums.dart` | Postgres ↔ Dart enum mapping, one function pair per enum |
| `lib/shared/data/db_failure.dart` | `DbFailure` + `mapPostgrestError` — one place that turns driver errors into messages a person can read |
| `lib/features/auth/data/datasources/supabase_auth_datasource.dart` | `AuthDataSource` against Postgres |
| `lib/shared/presentation/widgets/async_value_view.dart` | `AsyncInlineText` — skeleton/error/data rendering for a short value. The spec §7 calls for a shared `AsyncSection` for whole screens; this slice only ever needs the inline case, so `AsyncSection` is deferred to Plan 03 where the first full-screen async read appears |
| `test/shared/data/db_enums_test.dart` | Round-trip tests for every enum |
| `test/shared/data/db_failure_test.dart` | Error-mapping tests |

**Modified**

| File | Change |
|------|--------|
| `pubspec.yaml` | add `supabase_flutter` |
| `lib/main.dart` | `Supabase.initialize` before `runApp` |
| `lib/config/env/env.dart` | `isMockMode` reads a dart-define |
| `lib/features/auth/domain/repositories/auth_repository.dart` | `getUserById`, `getStaffAccounts` become `Future` |
| `lib/features/auth/data/datasources/auth_datasource.dart` | same |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | same |
| `lib/features/auth/data/datasources/mock_auth_datasource.dart` | same |
| `lib/features/auth/presentation/providers/auth_providers.dart` | datasource selection, async session restore, `userProfileProvider` |
| `lib/features/doctor/presentation/providers/staff_management_providers.dart` | becomes a `FutureProvider` |
| 16 widget files | read `userProfileProvider` instead of calling the repository |
| `lib/config/router/app_router.dart` | tolerate an in-flight session restore |
| `test/features/auth/mock_auth_datasource_test.dart` | `await` the two now-async calls |

---

## Task 1: Database prep — CLI config and Plan 01's deferred follow-ups

**Files:**
- Create: `supabase/config.toml`
- Create: `supabase/migrations/0016_plan02_prep.sql`
- Create: `supabase/tests/0017_plan02_prep_test.sql`

**Interfaces:**
- Consumes: the 27-table schema from Plan 01.
- Produces: `public.assign_default_doctor(p_patient uuid) returns uuid` — assigns the patient's clinic's first active doctor and returns the id. Task 7's sign-up calls it.

Plan 01's outcome doc lists eight follow-ups. Four are closed here because Task 8
cannot deploy an Edge Function without a CLI config, and Task 7 cannot complete a
sign-up without `assign_default_doctor`.

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/0017_plan02_prep_test.sql`:

```sql
-- Follow-up 1: DELETE grants must match the policies that were removed.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated may delete ' || string_agg(distinct table_name, ', ') end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'DELETE'
  and table_name in ('consultations','prescriptions','health_metrics',
                     'inventory_items','inventory_batches');

-- ...but the legitimate self-service deletes must survive.
select case when count(*) = 3 then 'PASS'
            else 'FAIL: only ' || count(*) || ' of 3 self-delete paths remain' end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'DELETE'
  and table_name in ('goal_progress','chat_conversations','chat_messages');

-- Follow-up: sign-up needs a server-side doctor assignment, because clients
-- cannot write assigned_doctor_id.
select case when count(*) = 1 then 'PASS' else 'FAIL: assign_default_doctor missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'assign_default_doctor';

-- Final-review follow-up 3: decide_leave must not leak a status oracle across
-- clinics — the clinic check has to precede the existence/status checks.
select case when position('not your clinic' in def) < position('already' in def) then 'PASS'
            else 'FAIL: clinic check still runs after the status check' end as status
from (select pg_get_functiondef(p.oid) as def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'decide_leave') s;
```

- [ ] **Step 2: Run each assertion separately and confirm RED**

Use `execute_sql`, one call per `select`. Expect: FAIL on DELETE grants, PASS on
the self-delete check (already true), FAIL on `assign_default_doctor`, FAIL on
the oracle ordering. **Report the actual results** — if the second assertion is
already PASS that is expected, not a vacuous pass to hide.

- [ ] **Step 3: Write the migration**

Create `supabase/migrations/0016_plan02_prep.sql`:

```sql
-- Plan 01 removed the DELETE policies on these five but not the table grants,
-- leaving the grant and policy layers disagreeing. RLS already denies, so this
-- closes an inconsistency rather than a hole.
revoke delete on public.consultations     from authenticated;
revoke delete on public.prescriptions     from authenticated;
revoke delete on public.health_metrics    from authenticated;
revoke delete on public.inventory_items   from authenticated;
revoke delete on public.inventory_batches from authenticated;

-- Nothing client-side can set patient_profiles.assigned_doctor_id — Plan 01
-- revoked that column deliberately, so a patient cannot pick their own doctor.
-- Sign-up still has to assign one, so it happens here with definer rights.
create or replace function public.assign_default_doctor(p_patient uuid)
returns uuid
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_clinic uuid;
  v_doctor uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_patient <> auth.uid() and public.auth_role() <> 'doctor' then
    raise exception 'may only assign a doctor to your own profile'
      using errcode = '42501';
  end if;

  select clinic_id into v_clinic from public.profiles where id = p_patient;
  if v_clinic is null then
    raise exception 'no profile for that patient' using errcode = 'P0002';
  end if;

  -- Fewest current patients first, so sign-ups spread across the clinic
  -- instead of all landing on whichever doctor sorts first.
  select d.id into v_doctor
  from public.doctor_profiles d
  join public.profiles p on p.id = d.id
  left join public.patient_profiles pp on pp.assigned_doctor_id = d.id
  where d.clinic_id = v_clinic and p.is_active
  group by d.id
  order by count(pp.id), d.id
  limit 1;

  if v_doctor is null then
    raise exception 'that clinic has no active doctor' using errcode = 'P0002';
  end if;

  update public.patient_profiles set assigned_doctor_id = v_doctor where id = p_patient;
  return v_doctor;
end;
$$;

revoke all on function public.assign_default_doctor(uuid) from public, anon;
grant execute on function public.assign_default_doctor(uuid) to authenticated;

-- decide_leave raised "not found" / "already decided" before its clinic check,
-- so a doctor holding a request UUID could distinguish states at other clinics.
-- Same body, clinic check moved above the status checks.
create or replace function public.decide_leave(
  p_request uuid, p_status public.leave_status
)
returns public.leave_requests
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_row       public.leave_requests;
  v_cancelled int := 0;
  v_current   public.leave_status;
begin
  if public.auth_role() <> 'doctor' then
    raise exception 'only doctors decide leave' using errcode = '42501';
  end if;
  if p_status = 'pending' then
    raise exception 'decision must be approved or denied' using errcode = '22023';
  end if;

  -- Clinic first: a caller outside the clinic learns nothing about whether the
  -- request exists or what state it is in.
  if not exists (select 1 from public.profiles p
                  join public.leave_requests l on l.staff_id = p.id
                 where l.id = p_request and p.clinic_id = public.auth_clinic()) then
    raise exception 'that staff member is not at your clinic' using errcode = '42501';
  end if;

  select status into v_current from public.leave_requests where id = p_request;
  if v_current is null then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;
  if v_current <> 'pending' then
    raise exception 'leave request was already %', v_current using errcode = '22023';
  end if;

  update public.leave_requests
     set status = p_status, decided_by = auth.uid(), decided_at = now()
   where id = p_request
   returning * into v_row;

  if p_status = 'approved' then
    update public.appointments
       set status = 'cancelled'
     where doctor_id = v_row.staff_id
       and status <> 'cancelled'
       and (scheduled_at at time zone 'UTC')::date
           between v_row.start_date and v_row.end_date;

    get diagnostics v_cancelled = row_count;
  end if;

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
```

- [ ] **Step 4: Apply the migration**

`apply_migration`, `name: "plan02_prep"`, `project_id: "arxrtodtnrmhwbecwyxm"`.

- [ ] **Step 5: Re-run each assertion and confirm four PASS**

- [ ] **Step 6: Write the CLI config**

Create `supabase/config.toml`. Without this the CLI cannot run at all, which
blocks Task 8's function deploy:

```toml
project_id = "arxrtodtnrmhwbecwyxm"

[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000

[db]
port = 54322
shadow_port = 54320
major_version = 17

[studio]
enabled = true
port = 54323

[auth]
enabled = true
site_url = "http://localhost:3000"
additional_redirect_urls = ["https://localhost:3000"]
jwt_expiry = 3600
enable_refresh_token_rotation = true
refresh_token_reuse_interval = 10
enable_signup = true

[auth.email]
enable_signup = true
double_confirm_changes = true
# Demo accounts are seeded with confirmed emails; requiring confirmation here
# would break local sign-up testing against a fresh `db reset`.
enable_confirmations = false

[functions.create-staff-account]
verify_jwt = true
```

- [ ] **Step 7: Document the migration-version mismatch**

Plan 01's files are named `0001_…`–`0015_…` while the applied versions are
timestamps, so `supabase migration list` shows every local migration as
un-applied. Do **not** rename the files — the applied history is the source of
truth and renaming would not change it. Append to
`docs/superpowers/plans/2026-08-22-supabase-database-foundation-OUTCOME.md`
under "Outstanding follow-ups":

```markdown
### Resolved in Plan 02

- `supabase/config.toml` added (follow-up 5).
- Follow-ups 1 and 3 from the final review closed by `0016_plan02_prep.sql`.
- `assign_default_doctor` added (follow-up 8).
- **Follow-up 4 deliberately not fixed by renaming.** Local files are `NNNN_`;
  applied versions are timestamps. Before anyone runs `supabase db push`, run
  `supabase migration repair --status applied <version>` for each applied
  version, or the push will try to re-run migrations whose bare `create table`
  statements will fail partway. Renaming the files does not reconcile this.
```

- [ ] **Step 8: Commit**

```bash
git add supabase/config.toml supabase/migrations/0016_plan02_prep.sql \
        supabase/tests/0017_plan02_prep_test.sql docs/superpowers/plans
git commit -m "feat(db): add CLI config, doctor assignment and plan 01 follow-ups"
```

---

## Task 2: Add the Supabase client

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/config/env/supabase_config.dart`
- Create: `lib/shared/data/supabase_providers.dart`
- Modify: `lib/config/env/env.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `supabaseClientProvider` → `SupabaseClient`; `Env.isMockMode` → `bool`; `SupabaseConfig.url` / `SupabaseConfig.publishableKey` → `String`.

- [ ] **Step 1: Add the dependency**

```bash
flutter pub add supabase_flutter
flutter pub get
```

- [ ] **Step 2: Write the config**

Create `lib/config/env/supabase_config.dart`:

```dart
/// Connection details for the MyPulse360 Supabase project.
///
/// The publishable key is meant to ship inside the client — it is what the
/// app authenticates the *anonymous* role with before a user signs in. It is
/// safe to commit *because* row-level security stands between it and the
/// data, not because the key itself is secret. The service-role key is a
/// different thing entirely and lives only in the Edge Function environment.
abstract final class SupabaseConfig {
  static const String url = 'https://arxrtodtnrmhwbecwyxm.supabase.co';

  static const String publishableKey =
      'sb_publishable_RLksAvPtIo1rAepq03Pavg_p80valSC';

  const SupabaseConfig._();
}
```

- [ ] **Step 3: Make the mock switch real**

Replace `lib/config/env/env.dart` entirely:

```dart
/// Which backend the app talks to.
///
/// Defaults to the real Supabase project. Pass
/// `--dart-define=MYPULSE_MOCK=true` to run against the in-memory
/// [MockDatabase] instead — which is what the widget tests and a
/// no-network demo need.
abstract final class Env {
  static const bool isMockMode =
      bool.fromEnvironment('MYPULSE_MOCK', defaultValue: false);

  const Env._();
}
```

- [ ] **Step 4: Write the client provider**

Create `lib/shared/data/supabase_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single point every datasource reaches the backend through.
///
/// Throws if read before [Supabase.initialize] has run, which is deliberate:
/// a datasource constructed too early should fail loudly at startup rather
/// than return a client that silently has no session.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

- [ ] **Step 5: Initialise before runApp**

In `lib/main.dart`, add the imports and initialise between the Hive setup and
`runApp`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env/env.dart';
import 'config/env/supabase_config.dart';
```

```dart
  await Hive.initFlutter();
  await Hive.openBox(HiveBoxes.settings);

  // Skipped in mock mode so tests and the offline demo never touch the
  // network. Everything downstream selects its datasource on the same flag.
  if (!Env.isMockMode) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
  }

  runApp(const ProviderScope(child: MyPulse360App()));
```

- [ ] **Step 6: Verify the app still builds and tests pass**

```bash
flutter analyze
flutter test
```

Expected: no issues, 91/91 passing. The tests run without
`--dart-define`, so `Env.isMockMode` is `false` for them — but they construct
datasources directly and never call `Supabase.instance`, so they are unaffected.
**If any test fails here, stop and report** — it means something reads the
client at import time.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/config/env lib/shared/data lib/main.dart
git commit -m "feat(auth): add supabase_flutter client and mock-mode switch"
```

---

## Task 3: Enum and error mapping

**Files:**
- Create: `lib/shared/data/db_enums.dart`
- Create: `lib/shared/data/db_failure.dart`
- Test: `test/shared/data/db_enums_test.dart`
- Test: `test/shared/data/db_failure_test.dart`

**Interfaces:**
- Produces: `userRoleFromDb(String) → UserRole`, `userRoleToDb(UserRole) → String`, and the same pair for every other enum this slice needs; `DbFailure` with `.message`; `mapPostgrestError(Object) → DbFailure`.

Pure functions with no I/O, so unlike the rest of this plan they are genuinely
unit-testable. Doing them first means Task 6 has no string literals in it.

- [ ] **Step 1: Write the failing tests**

Create `test/shared/data/db_enums_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/shared/data/db_enums.dart';

void main() {
  group('userRole mapping', () {
    test('round-trips every value', () {
      for (final role in UserRole.values) {
        expect(userRoleFromDb(userRoleToDb(role)), role);
      }
    });

    test('uses the snake_case labels Postgres stores', () {
      expect(userRoleToDb(UserRole.patient), 'patient');
      expect(userRoleToDb(UserRole.doctor), 'doctor');
      expect(userRoleToDb(UserRole.pharmacist), 'pharmacist');
    });

    test('throws on an unknown label rather than guessing', () {
      expect(() => userRoleFromDb('administrator'), throwsArgumentError);
    });
  });
}
```

Create `test/shared/data/db_failure_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/shared/data/db_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapPostgrestError', () {
    test('turns a taken slot into words a patient understands', () {
      final failure = mapPostgrestError(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(failure.message, 'That time slot was just taken. Please pick another.');
    });

    test('turns a permission error into a refusal, not a stack trace', () {
      final failure = mapPostgrestError(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );
      expect(failure.message, "You don't have permission to do that.");
    });

    test('reports bad credentials without revealing which half was wrong', () {
      final failure = mapPostgrestError(
        const AuthException('Invalid login credentials'),
      );
      expect(failure.message, 'That email and password do not match.');
    });

    test('falls back to a generic message and keeps the cause for logging', () {
      final failure = mapPostgrestError(StateError('something odd'));
      expect(failure.message, 'Something went wrong. Please try again.');
      expect(failure.cause, isA<StateError>());
    });
  });
}
```

- [ ] **Step 2: Run them and confirm RED**

```bash
flutter test test/shared/data/
```

Expected: compilation failure — `db_enums.dart` and `db_failure.dart` do not exist.

- [ ] **Step 3: Write the enum mapping**

Create `lib/shared/data/db_enums.dart`:

```dart
import '../../features/auth/domain/entities/user_role.dart';

/// Postgres stores enum labels in snake_case; Dart spells them lowerCamelCase.
/// Every translation lives here so a datasource never contains a bare string,
/// and so adding an enum value fails in one place rather than silently
/// mis-mapping at the edges.

const _userRoleToDb = <UserRole, String>{
  UserRole.patient: 'patient',
  UserRole.doctor: 'doctor',
  UserRole.pharmacist: 'pharmacist',
};

String userRoleToDb(UserRole role) => _userRoleToDb[role]!;

UserRole userRoleFromDb(String label) {
  for (final entry in _userRoleToDb.entries) {
    if (entry.value == label) return entry.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown user_role from the database');
}
```

- [ ] **Step 4: Write the error mapping**

Create `lib/shared/data/db_failure.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// A backend error with a message that can be shown to a person.
///
/// [cause] is kept for logging and never displayed — raw Postgres text leaks
/// table and column names.
class DbFailure implements Exception {
  const DbFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Translates a driver error into something a patient can act on.
///
/// The Postgres codes here are the ones the RPCs in Plan 01 raise
/// deliberately: 23505 when a slot is taken, 23514 on insufficient stock,
/// 42501 when a policy or grant refuses the caller.
DbFailure mapPostgrestError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return DbFailure('That email and password do not match.', cause: error);
    }
    if (message.contains('already registered')) {
      return DbFailure('An account with that email already exists.', cause: error);
    }
    return DbFailure(error.message, cause: error);
  }

  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return DbFailure(
            'That time slot was just taken. Please pick another.', cause: error);
      case '23514':
        return DbFailure(
            'There is not enough stock to dispense that amount.', cause: error);
      case '42501':
      case '28000':
        return DbFailure("You don't have permission to do that.", cause: error);
      case 'P0002':
        return DbFailure('We could not find that record.', cause: error);
    }
    return DbFailure('Something went wrong. Please try again.', cause: error);
  }

  return DbFailure('Something went wrong. Please try again.', cause: error);
}
```

- [ ] **Step 5: Run and confirm GREEN**

```bash
flutter test test/shared/data/
flutter analyze
```

Expected: all passing, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/data/db_enums.dart lib/shared/data/db_failure.dart test/shared/data
git commit -m "feat(data): add enum and error mapping for the Postgres layer"
```

---

## Task 4: Make the auth interfaces async

**Files:**
- Modify: `lib/features/auth/domain/repositories/auth_repository.dart`
- Modify: `lib/features/auth/data/datasources/auth_datasource.dart`
- Modify: `lib/features/auth/data/repositories/auth_repository_impl.dart`
- Modify: `lib/features/auth/data/datasources/mock_auth_datasource.dart`
- Modify: `test/features/auth/mock_auth_datasource_test.dart`

**Interfaces:**
- Produces: `Future<AppUser?> getUserById(String)`, `Future<List<AppUser>> getStaffAccounts()`. Every other method is already `Future`.

This task deliberately breaks 16 widget call sites. **They are fixed in Task 5,
not here** — this commit will not analyze clean on its own, so Tasks 4 and 5 are
committed together at the end of Task 5. Do the interface change first so the
compiler produces the exact list of call sites to fix.

- [ ] **Step 1: Change the two signatures in the domain interface**

In `lib/features/auth/domain/repositories/auth_repository.dart`:

```dart
  /// Doctor/pharmacist accounts only — backs the staff management screen.
  Future<List<AppUser>> getStaffAccounts();

  Future<void> logout();

  Future<AppUser?> getUserById(String id);
```

- [ ] **Step 2: Mirror them in the datasource interface**

In `lib/features/auth/data/datasources/auth_datasource.dart`:

```dart
  Future<List<AppUser>> getStaffAccounts();

  Future<AppUser?> getUserById(String id);
```

- [ ] **Step 3: Mirror them in the repository implementation**

In `lib/features/auth/data/repositories/auth_repository_impl.dart`:

```dart
  @override
  Future<List<AppUser>> getStaffAccounts() => _dataSource.getStaffAccounts();

  @override
  Future<void> logout() async {}

  @override
  Future<AppUser?> getUserById(String id) => _dataSource.getUserById(id);
```

- [ ] **Step 4: Make the mock satisfy them**

In `lib/features/auth/data/datasources/mock_auth_datasource.dart`, change the two
method signatures to return `Future` and add `async`. The bodies are unchanged —
returning a value from an `async` function wraps it automatically:

```dart
  @override
  Future<List<AppUser>> getStaffAccounts() async =>
      _db.users.where((u) => u.role != UserRole.patient).toList();

  @override
  Future<AppUser?> getUserById(String id) async => _db.userById(id);
```

- [ ] **Step 5: Await them in the existing tests**

In `test/features/auth/mock_auth_datasource_test.dart`, three assertions call
`getUserById` synchronously. Wrap each call:

```dart
      expect((await dataSource.getUserById(pharmacist.id))!.mustChangePassword, isFalse);
```

```dart
      expect((await dataSource.getUserById(pharmacist.id))!.isActive, isFalse);
```

```dart
      expect((await dataSource.getUserById(pharmacist.id))!.isActive, isTrue);
```

- [ ] **Step 6: Add `logout()` to the datasource interface**

`AuthDataSource` has no `logout()` today — `AuthRepositoryImpl.logout()` is a
no-op, which was harmless for an in-memory mock and is not harmless for a
persisted Supabase session. Without this, "log out" would leave the session
intact and the next launch would silently sign the user back in.

Add to `lib/features/auth/data/datasources/auth_datasource.dart`:

```dart
  Future<void> logout();
```

Add to `lib/features/auth/data/datasources/mock_auth_datasource.dart` (the mock
has no session to end, so it stays a no-op — but an explicit one):

```dart
  @override
  Future<void> logout() async {}
```

And in `lib/features/auth/data/repositories/auth_repository_impl.dart`, stop
swallowing it:

```dart
  @override
  Future<void> logout() => _dataSource.logout();
```

- [ ] **Step 7: Confirm the compiler lists exactly the expected breakage**

```bash
flutter analyze
```

Expected: errors **only** at the 16 widget call sites plus
`lib/features/auth/presentation/providers/auth_providers.dart` and
`lib/features/doctor/presentation/providers/staff_management_providers.dart`.
Record the list — Task 5 works through it. **If an error appears anywhere else,
stop and report**: it means a call site exists that this plan did not account for.

Do not commit yet. Continue to Task 5.

---

## Task 5: Move the 16 call sites onto a provider

**Files:**
- Create: `lib/shared/presentation/widgets/async_value_view.dart`
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart` (add `userProfileProvider`)
- Modify: `lib/features/doctor/presentation/providers/staff_management_providers.dart`
- Modify: the 16 widget files listed below

**Interfaces:**
- Consumes: the async repository from Task 4.
- Produces: `userProfileProvider` — `FutureProvider.family<AppUser?, String>`; `AsyncInlineText` widget.

This is one batched change of the same shape repeated 16 times. Do it as a
single pass, not sixteen.

- [ ] **Step 1: Add the provider**

In `lib/features/auth/presentation/providers/auth_providers.dart`, after
`currentUserProvider`:

```dart
/// One profile, by id. Widgets that show a doctor's or patient's name read
/// this instead of calling the repository, because that call is a network
/// round trip now and a `build()` cannot await.
///
/// Not auto-disposed: the same handful of ids are read across many screens,
/// and re-fetching a name on every navigation is wasted latency.
final userProfileProvider = FutureProvider.family<AppUser?, String>((ref, id) {
  return ref.watch(authRepositoryProvider).getUserById(id);
});
```

- [ ] **Step 2: Add the shared async rendering**

Create `lib/shared/presentation/widgets/async_value_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_theme.dart';

/// Renders a short piece of text that is still loading — a name, usually.
///
/// A skeleton bar rather than a spinner: at this size a spinner draws more
/// attention than the value deserves, and an empty string would make the
/// layout jump once the value lands.
class AsyncInlineText extends StatelessWidget {
  const AsyncInlineText({
    super.key,
    required this.value,
    required this.builder,
    this.width = 120,
    this.style,
  });

  final AsyncValue<String?> value;
  final Widget Function(String text) builder;
  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return value.when(
      data: (text) => builder(text ?? 'Unknown'),
      error: (_, _) => Text('Unavailable', style: style ?? TextStyle(color: colors.textTertiary)),
      loading: () => Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Convert the 16 call sites**

Each is the same edit. The old form:

```dart
final doctor = ref.watch(authRepositoryProvider).getUserById(appointment.doctorId);
```

becomes:

```dart
final doctor = ref.watch(userProfileProvider(appointment.doctorId)).valueOrNull;
```

`valueOrNull` is correct at these sites specifically: every one of them already
handled `null` (the user might not exist), and each renders a *name beside* the
real content rather than the content itself. Where the name is the only thing on
the line, use `AsyncInlineText` instead so the reader sees a skeleton rather than
"Unknown" flashing to a real name.

The files and lines:

| File | Line |
|------|------|
| `lib/features/appointments/presentation/pages/appointments_list_page.dart` | 137 |
| `lib/features/appointments/presentation/pages/appointment_detail_page.dart` | 48 |
| `lib/features/appointments/presentation/pages/book_appointment_page.dart` | 81 |
| `lib/features/appointments/presentation/pages/queue_number_page.dart` | 77 |
| `lib/features/appointments/presentation/pages/reschedule_page.dart` | 52 |
| `lib/features/doctor/presentation/pages/doctor_dashboard_page.dart` | 239 |
| `lib/features/doctor/presentation/pages/patient_history_page.dart` | 72 |
| `lib/features/health_dashboard/presentation/pages/dashboard_page.dart` | 46 |
| `lib/features/pharmacist/presentation/pages/create_prescription_page.dart` | 64 |
| `lib/features/pharmacist/presentation/pages/pharmacist_dashboard_page.dart` | 69, 117 |
| `lib/features/pharmacist/presentation/pages/pharmacist_prescriptions_page.dart` | 58 |
| `lib/features/pharmacist/presentation/pages/prescription_verification_page.dart` | 70 |
| `lib/features/prescriptions/presentation/widgets/prescription_card.dart` | 30 |

`prescription_card.dart:30` chains `?.fullName`, so it becomes:

```dart
        : ref.watch(userProfileProvider(prescription.doctorId)).valueOrNull?.fullName;
```

- [ ] **Step 4: Convert the staff-accounts provider**

In `lib/features/doctor/presentation/providers/staff_management_providers.dart`,
`staffAccountsProvider` becomes a `FutureProvider`. `staffAccountsRevisionProvider`
is unchanged — it still forces a re-read after any staff mutation:

```dart
/// Doctor + pharmacist accounts — backs the doctor-only Staff Management
/// screen. Never includes patients.
final staffAccountsProvider = FutureProvider<List<AppUser>>((ref) {
  ref.watch(staffAccountsRevisionProvider);
  return ref.watch(authRepositoryProvider).getStaffAccounts();
});
```

It has exactly one consumer, `lib/features/doctor/presentation/pages/staff_management_page.dart:27`:

```dart
    final staff = ref.watch(staffAccountsProvider);
```

Render the three states there rather than reaching for `valueOrNull` — this is
the screen's whole content, not a name beside something else, so a half-drawn
staff list would be a lie:

```dart
    return ref.watch(staffAccountsProvider).when(
      data: (staff) => _StaffList(staff: staff),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
```

Wrap whatever the page currently builds from `staff` in `_StaffList`, or inline
the existing body into the `data:` branch — whichever is the smaller edit for
how that file is structured.

- [ ] **Step 5: Fix the two auth provider call sites**

In `auth_providers.dart`, `build()` and `changePassword` both call
`getUserById`. `build()` is handled properly in Task 9; for now make it
compile by returning `AuthUnauthenticated()` when there is a stored id and
letting Task 9 replace the whole method:

```dart
  @override
  AuthState build() {
    // Session restore becomes async in Task 9. Until then, start
    // unauthenticated and let the login screen drive.
    return const AuthUnauthenticated();
  }
```

and in `changePassword`:

```dart
      state = AuthAuthenticated((await repository.getUserById(current.user.id))!);
```

- [ ] **Step 6: Verify**

```bash
flutter analyze
flutter test
```

Expected: no issues, 91/91 passing.

- [ ] **Step 7: Commit Tasks 4 and 5 together**

```bash
git add lib test
git commit -m "refactor(auth): make profile lookups async behind a provider"
```

---

## Task 6: SupabaseAuthDataSource — login, logout, lookup

**Files:**
- Create: `lib/features/auth/data/datasources/supabase_auth_datasource.dart`
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart` (datasource selection)

**Interfaces:**
- Consumes: `supabaseClientProvider` (Task 2), `userRoleFromDb` / `userRoleToDb` / `mapPostgrestError` / `DbFailure` (Task 3), the async `AuthDataSource` including `logout()` (Task 4).
- Produces: `SupabaseAuthDataSource implements AuthDataSource`. Its private `_toUser(Map<String, dynamic>) → AppUser` and `_profileFor(String) → Future<AppUser>` are used again by Tasks 7 and 8.

- [ ] **Step 1: Write the datasource**

Create `lib/features/auth/data/datasources/supabase_auth_datasource.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_enums.dart';
import '../../../../shared/data/db_failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import 'auth_datasource.dart';

/// Auth against Supabase. Sessions are persisted by the SDK, so nothing here
/// stores a user id — `client.auth.currentUser` is the source of truth.
class SupabaseAuthDataSource implements AuthDataSource {
  SupabaseAuthDataSource(this._client);

  final SupabaseClient _client;

  static const _profileColumns =
      'id, email, full_name, role, clinic_id, phone, avatar_url, is_active, must_change_password';

  AppUser _toUser(Map<String, dynamic> row) => AppUser(
        id: row['id'] as String,
        email: row['email'] as String,
        fullName: row['full_name'] as String,
        role: userRoleFromDb(row['role'] as String),
        clinicId: row['clinic_id'] as String,
        phone: row['phone'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        isActive: row['is_active'] as bool,
        mustChangePassword: row['must_change_password'] as bool,
      );

  Future<AppUser> _profileFor(String id) async {
    final row = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const DbFailure('Your account has no profile. Contact the clinic.');
    }
    return _toUser(row);
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
    required bool isWebPlatform,
  }) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      final id = response.user?.id;
      if (id == null) {
        throw const DbFailure('That email and password do not match.');
      }

      final user = await _profileFor(id);

      // Same two refusals the mock enforces: a deactivated account cannot
      // sign in even with the right password, and staff sign in through the
      // web dashboard only. Sign out again so a refused login leaves no
      // usable session behind.
      if (!user.isActive) {
        await _client.auth.signOut();
        throw const DbFailure('That account has been deactivated.');
      }
      if (!isWebPlatform && user.role != UserRole.patient) {
        await _client.auth.signOut();
        throw const DbFailure('Staff accounts sign in on the web dashboard.');
      }

      return user;
    } on DbFailure {
      rethrow;
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    throw UnimplementedError('Sign-up lands in Task 7');
  }

  @override
  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  }) async {
    throw UnimplementedError('Staff creation lands in Task 8');
  }

  @override
  Future<void> setAccountActive({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _client.from('profiles').update({'is_active': isActive}).eq('id', userId);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    throw UnimplementedError('Password change lands in Task 7');
  }

  @override
  Future<List<AppUser>> getStaffAccounts() async {
    try {
      final rows = await _client
          .from('profiles')
          .select(_profileColumns)
          .neq('role', userRoleToDb(UserRole.patient))
          .order('full_name');
      return rows.map((r) => _toUser(r)).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> logout() async => _client.auth.signOut();

  @override
  Future<AppUser?> getUserById(String id) async {
    try {
      final row = await _client
          .from('profiles')
          .select(_profileColumns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _toUser(row);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
}
```

- [ ] **Step 2: Select the datasource by mode**

In `auth_providers.dart`, replace `authRepositoryProvider`:

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final AuthDataSource dataSource = Env.isMockMode
      ? MockAuthDataSource(ref.watch(mockDatabaseProvider))
      : SupabaseAuthDataSource(ref.watch(supabaseClientProvider));
  return AuthRepositoryImpl(dataSource);
});
```

- [ ] **Step 3: Verify**

```bash
flutter analyze
flutter test
```

Expected: no issues, 91/91 passing. The tests construct `MockAuthDataSource`
directly, so the new branch is not exercised by them.

- [ ] **Step 4: Verify login against the live project**

There is no way to unit-test this without a network, so verify it by hand and
record the result. Run the app in Chrome (the staff path needs web):

```bash
flutter run -d chrome
```

Sign in as `aisha.rahman@mypulse360.test` / `Patient123!`. Expected: the patient
dashboard loads. Then sign in as `ahmed.rashid@mypulse360.test` / `Doctor123!` —
expected: the doctor dashboard loads on web.

**Report what actually happened**, including any error text. If the profile
fetch fails with a permission error, that is the `profiles_read_self` policy —
report it rather than loosening the policy.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth
git commit -m "feat(auth): sign in against Supabase with role and active checks"
```

---

## Task 7: Sign-up, doctor assignment and forced password change

**Files:**
- Modify: `lib/features/auth/data/datasources/supabase_auth_datasource.dart`

**Interfaces:**
- Consumes: `assign_default_doctor(uuid)` from Task 1.
- Produces: working `signUp` and `changePassword`.

- [ ] **Step 1: Implement sign-up**

Replace the `signUp` stub. A patient's `profiles` row is written by the client
because `profiles_insert_self` allows it; the doctor assignment is not, because
Plan 01 revoked that column deliberately.

```dart
  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final id = response.user?.id;
      if (id == null) {
        throw const DbFailure('Could not create that account. Please try again.');
      }

      // Self-service registration is always a patient. The role is written
      // here rather than accepted from the caller, and RLS will not let this
      // row name any other role for its own id.
      await _client.from('profiles').insert({
        'id': id,
        'email': email.trim(),
        'full_name': fullName.trim(),
        'role': userRoleToDb(UserRole.patient),
        'clinic_id': await _defaultClinicId(),
      });

      await _client.from('patient_profiles').insert({
        'id': id,
        'height_cm': 0,
        'weight_kg': 0,
      });

      // assigned_doctor_id is not client-writable, so the server picks.
      await _client.rpc('assign_default_doctor', params: {'p_patient': id});

      return _profileFor(id);
    } on DbFailure {
      rethrow;
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// The clinic a self-service sign-up joins. One clinic is the common case;
  /// picking the first by name keeps it deterministic until the app offers a
  /// chooser.
  Future<String> _defaultClinicId() async {
    final row = await _client.from('clinics').select('id').order('name').limit(1).maybeSingle();
    if (row == null) {
      throw const DbFailure('No clinic is configured. Contact support.');
    }
    return row['id'] as String;
  }
```

> `height_cm` and `weight_kg` are `not null` with no default, and the onboarding
> flow collects them at step 1. Zero is a deliberate placeholder that onboarding
> overwrites — if you would rather they be nullable, that is a schema change and
> belongs in its own task, not here.

- [ ] **Step 2: Implement the password change**

```dart
  @override
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      // Clearing the flag is what releases the router's forced-change gate.
      await _client
          .from('profiles')
          .update({'must_change_password': false}).eq('id', userId);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
```

- [ ] **Step 3: Verify sign-up end to end**

```bash
flutter run -d chrome
```

Register a new account. Expected: it lands on the onboarding welcome screen.
Then confirm the row was assigned a doctor — via `execute_sql`:

```sql
select p.email, d.full_name as assigned_doctor
from public.patient_profiles pp
join public.profiles p on p.id = pp.id
join public.profiles d on d.id = pp.assigned_doctor_id
order by p.created_at desc limit 3;
```

Expected: the new account appears with a doctor assigned. **Report the actual
output.** If `assigned_doctor` is null, `assign_default_doctor` did not run —
report it rather than setting the column another way.

- [ ] **Step 4: Verify the forced password change**

Sign in as `nur.hakim@mypulse360.test` / `Pharma123!` on web. That account is
seeded without `must_change_password`, so set it first:

```sql
update public.profiles set must_change_password = true
where email = 'nur.hakim@mypulse360.test';
```

Expected: login redirects to the forced-change screen, and after setting a new
password the pharmacist dashboard loads. Confirm the flag cleared:

```sql
select must_change_password from public.profiles where email = 'nur.hakim@mypulse360.test';
```

Expected: `false`. Reset the password back to `Pharma123!` afterwards so the
demo credentials in `seed.sql` stay accurate, and say so in your report.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth
git commit -m "feat(auth): sign up with server-side doctor assignment"
```

---

## Task 8: The create-staff-account Edge Function

**Files:**
- Create: `supabase/functions/create-staff-account/index.ts`
- Modify: `lib/features/auth/data/datasources/supabase_auth_datasource.dart`

**Interfaces:**
- Produces: `POST /functions/v1/create-staff-account` taking `{email, tempPassword, fullName, role, clinicId}` and returning the created profile row.

This is the only server-side code in the project. It exists because creating
another user's account needs the service-role key, which must never ship in a
Flutter binary.

- [ ] **Step 1: Write the function**

Create `supabase/functions/create-staff-account/index.ts`:

```ts
import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in.' }, 401);

  // Caller identity is established with the publishable key and the caller's
  // own JWT, so this respects RLS and cannot be spoofed by the request body.
  const caller = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) return json({ error: 'Not signed in.' }, 401);

  const { data: profile } = await caller
    .from('profiles').select('role, clinic_id').eq('id', user.id).maybeSingle();

  if (!profile || profile.role !== 'doctor') {
    return json({ error: 'Only doctors can create staff accounts.' }, 403);
  }

  const body = await req.json().catch(() => null);
  if (!body?.email || !body?.tempPassword || !body?.fullName || !body?.role) {
    return json({ error: 'Missing required fields.' }, 400);
  }
  if (body.role !== 'doctor' && body.role !== 'pharmacist') {
    return json({ error: 'Staff accounts must be doctor or pharmacist.' }, 400);
  }

  // A doctor provisions into their own clinic, whatever the body claims.
  const clinicId = profile.clinic_id;

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: body.email,
    password: body.tempPassword,
    email_confirm: true,
  });
  if (createError || !created.user) {
    return json({ error: createError?.message ?? 'Could not create that account.' }, 400);
  }

  const { data: inserted, error: insertError } = await admin
    .from('profiles')
    .insert({
      id: created.user.id,
      email: body.email,
      full_name: body.fullName,
      role: body.role,
      clinic_id: clinicId,
      must_change_password: true,
    })
    .select('id, email, full_name, role, clinic_id, phone, avatar_url, is_active, must_change_password')
    .single();

  if (insertError) {
    // Roll the auth user back so a failed insert does not strand an account
    // that can sign in but has no profile.
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: insertError.message }, 400);
  }

  return json(inserted, 201);
});
```

- [ ] **Step 2: Deploy it**

Use the MCP `deploy_edge_function` tool with `project_id: "arxrtodtnrmhwbecwyxm"`,
`name: "create-staff-account"`, and the file contents. `SUPABASE_URL`,
`SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected by the platform —
**do not add them as secrets and do not put them in the repo.**

- [ ] **Step 3: Call it from the datasource**

Replace the `createStaffAccount` stub:

```dart
  @override
  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-staff-account',
        body: {
          'email': email.trim(),
          'tempPassword': tempPassword,
          'fullName': fullName.trim(),
          'role': userRoleToDb(role),
          // Sent for completeness; the function uses the caller's own clinic
          // and ignores this, so a doctor cannot provision into another clinic.
          'clinicId': clinicId,
        },
      );

      final data = response.data;
      if (response.status != 201 || data is! Map) {
        final message = data is Map && data['error'] is String
            ? data['error'] as String
            : 'Could not create that account.';
        throw DbFailure(message);
      }
      return _toUser(Map<String, dynamic>.from(data));
    } on DbFailure {
      rethrow;
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
```

- [ ] **Step 4: Verify it refuses a non-doctor**

Sign in as the pharmacist on web and attempt staff creation from the staff
management screen (or call the endpoint directly with their JWT). Expected:
403 "Only doctors can create staff accounts." **Report the actual response.**

- [ ] **Step 5: Verify it works for a doctor**

Sign in as `ahmed.rashid@mypulse360.test` and create a pharmacist. Then confirm:

```sql
select email, role, must_change_password, clinic_id
from public.profiles where email = '<the address you used>';
```

Expected: role `pharmacist`, `must_change_password` true, `clinic_id` matching
Dr. Rashid's. Then sign in as that account and confirm it is forced to the
password-change screen.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions lib/features/auth
git commit -m "feat(auth): add create-staff-account edge function"
```

---

## Task 9: Async session restore and the router gate

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart`
- Modify: `lib/config/router/app_router.dart`
- Modify: `lib/features/auth/presentation/pages/splash_page.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: an `AuthController` whose `build()` restores a persisted Supabase session.

Today `build()` reads a user id from Hive synchronously. Supabase persists its
own session, so the id is no longer ours to store — but fetching the profile for
it is a network call, and `build()` cannot await.

- [ ] **Step 1: Restore the session asynchronously**

Replace `AuthController.build()` and add the restore:

```dart
  @override
  AuthState build() {
    if (Env.isMockMode) {
      final storedId = _box.get(HiveBoxes.keyCurrentUserId) as String?;
      if (storedId == null) return const AuthUnauthenticated();
      // Mock lookups are in-memory, so this future completes synchronously
      // enough that the splash screen never appears.
      _restore(storedId);
      return const AuthLoading();
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthUnauthenticated();
    _restore(session.user.id);
    return const AuthLoading();
  }

  /// Fetches the profile behind an already-valid session. A failure here
  /// means the session is good but the profile is not readable, which is a
  /// real error rather than a reason to show the login screen.
  Future<void> _restore(String userId) async {
    try {
      final user = await ref.read(authRepositoryProvider).getUserById(userId);
      state = user == null ? const AuthUnauthenticated() : AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }
```

- [ ] **Step 2: Store the id only in mock mode**

In `login` and `signUp`, the Hive write is now only meaningful for the mock —
Supabase persists its own session. Guard both:

```dart
      if (Env.isMockMode) {
        await _box.put(HiveBoxes.keyCurrentUserId, user.id);
      }
```

and in `logout`:

```dart
      if (Env.isMockMode) {
        await _box.delete(HiveBoxes.keyCurrentUserId);
      }
```

- [ ] **Step 3: Hold the splash screen while the restore is in flight**

In `app_router.dart`'s `redirect`, `AuthLoading` currently falls into the
`is! AuthAuthenticated` branch and bounces to login — which would flash the
login screen for anyone with a valid session. Add the guard immediately after
the splash check:

```dart
      final authState = ref.read(authControllerProvider);

      // A restore is in flight. Stay on the splash screen rather than
      // flashing the login page at someone who is already signed in.
      if (authState is AuthLoading) {
        return loc == RoutePaths.splash ? null : RoutePaths.splash;
      }

      final isAuthRoute = loc == RoutePaths.login || loc == RoutePaths.signUp;
```

and change the early return so splash is not skipped while loading:

```dart
      if (loc == RoutePaths.splash && authState is! AuthLoading) return null;
```

- [ ] **Step 4: Verify session persistence by hand**

```bash
flutter run -d chrome
```

Sign in as the patient, then reload the page. Expected: the splash screen
appears briefly and the dashboard returns without a second login. Then sign out
and reload — expected: the login screen, no flash of a dashboard.

**Report what you actually saw**, including whether the login screen flashed.

- [ ] **Step 5: Verify**

```bash
flutter analyze
flutter test
```

Expected: no issues, 91/91 passing.

- [ ] **Step 6: Commit**

```bash
git add lib
git commit -m "feat(auth): restore a persisted supabase session on launch"
```

---

## Task 10: End-to-end verification

**Files:**
- Create: `docs/superpowers/plans/2026-08-23-supabase-auth-slice-OUTCOME.md`

No code. This task exists because everything above was verified in pieces, and
the point of the slice is that the pieces work together.

- [ ] **Step 1: Run the full matrix**

For each row, record what actually happened — not what should have happened.

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Patient signs in on mobile | Dashboard loads |
| 2 | Doctor signs in on mobile | Refused: "Staff accounts sign in on the web dashboard." |
| 3 | Doctor signs in on web | Doctor dashboard loads |
| 4 | Wrong password | "That email and password do not match." — no stack trace, no Postgres text |
| 5 | Deactivated account signs in | Refused, and no session remains |
| 6 | New sign-up | Onboarding starts; a doctor is assigned server-side |
| 7 | Reload with a session | Splash, then dashboard — no login flash |
| 8 | Sign out then reload | Login screen |
| 9 | Doctor creates a pharmacist | Created with `must_change_password` |
| 10 | Pharmacist tries to create staff | 403 |
| 11 | New staff first sign-in | Forced to the password-change screen |
| 12 | `--dart-define=MYPULSE_MOCK=true` | App runs entirely on the mock, no network |

For row 5, deactivate an account first and reactivate it after:

```sql
update public.profiles set is_active = false where email = 'daniel.okafor@mypulse360.test';
```

- [ ] **Step 2: Confirm nothing regressed**

```bash
flutter analyze
flutter test
```

Expected: no issues, 91/91 passing.

- [ ] **Step 3: Run the Plan 01 suites again**

Run `supabase/tests/0015_rls_isolation_test.sql` and
`supabase/tests/0016_rpc_behaviour_test.sql` block by block. Expected: all PASS.
Real sign-ups have added rows since Plan 01, so **the exact-count assertions in
`0014_seed_test.sql` may now fail legitimately** — if they do, report it and
scope them to the seeded ids rather than deleting the new rows.

- [ ] **Step 4: Write the outcome doc**

Create `docs/superpowers/plans/2026-08-23-supabase-auth-slice-OUTCOME.md` with:
the matrix results, anything that behaved differently from this plan, follow-ups
for Plan 03, and any deferred item this slice closed.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans
git commit -m "docs: record the auth slice outcome"
```

---

## Done criteria

- [ ] All 12 matrix rows verified with recorded results
- [ ] `flutter analyze` clean, 91/91 Dart tests passing
- [ ] Plan 01's isolation and RPC suites still pass
- [ ] `--dart-define=MYPULSE_MOCK=true` still runs the app fully offline
- [ ] No service-role key anywhere in the repo
- [ ] Sign-up assigns a doctor server-side, and no client can write `assigned_doctor_id`

## Next plan

Plan 03 — the appointments slice: `available_slots` and `book_appointment` behind
`FutureProvider`/`StreamProvider`, the live queue via Postgres realtime, and the
"that slot was just taken" path the `23505` mapping in Task 3 already handles.
