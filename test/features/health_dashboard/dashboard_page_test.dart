// Guards the fix in dashboard_page.dart: the "Your Goals This Week" section
// must not claim "No goals yet" while the goals fetch is still in flight.
// Before the fix, `goals = wellnessGoalsProvider(...).valueOrNull ?? []`
// collapsed a not-yet-settled fetch into an empty list, and an empty list
// rendered that text unconditionally — telling a patient with real goals
// that they have none, on every cold load.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/auth/domain/entities/app_user.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/features/auth/presentation/providers/auth_providers.dart';
import 'package:mypulse360/features/auth/presentation/state/auth_state.dart';
import 'package:mypulse360/features/appointments/presentation/providers/appointments_providers.dart';
import 'package:mypulse360/features/health_dashboard/presentation/pages/dashboard_page.dart';
import 'package:mypulse360/features/health_dashboard/presentation/widgets/wellness_goal_row.dart';
import 'package:mypulse360/features/patient/domain/entities/patient_profile.dart';
import 'package:mypulse360/features/patient/domain/entities/wellness_goal.dart';
import 'package:mypulse360/features/patient/presentation/providers/patient_providers.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

const _patientUser = AppUser(
  id: 'patient-1',
  email: 'patient@example.com',
  fullName: 'Pat Ient',
  role: UserRole.patient,
  clinicId: 'clinic-1',
);

const _profile = PatientProfile(
  id: 'patient-1',
  heightCm: 170,
  weightKg: 70,
  allergies: [],
  chronicConditions: [],
  currentMedications: [],
  assignedDoctorId: 'user-dr-ahmed',
);

final _goal = WellnessGoal(
  id: 'goal-1',
  patientId: 'patient-1',
  type: WellnessGoalType.exercise,
  name: 'Walk 30 minutes',
  targetValue: 5,
  currentValue: 2,
  unit: 'days',
  status: GoalStatus.onTrack,
  targetDate: DateTime.now().add(const Duration(days: 7)),
);

const _noGoalsText = 'No goals yet — add some from your profile.';

void main() {
  testWidgets(
    'the goals section waits for the fetch to settle instead of claiming '
    '"No goals yet" while it is still loading',
    (tester) async {
      // Tall enough that every section renders without needing a scroll —
      // ListView only builds what's in the viewport, and an unbuilt widget
      // absent from the tree would be indistinguishable from a correctly
      // suppressed one.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final goalsCompleter = Completer<List<WellnessGoal>>();

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(const AuthAuthenticated(_patientUser)),
          ),
          patientProfileProvider.overrideWith(
            (ref, patientId) async => _profile,
          ),
          wellnessGoalsProvider.overrideWith(
            (ref, patientId) => goalsCompleter.future,
          ),
          // Avoids the real repository, which would reach for a live
          // Supabase client outside mock mode — irrelevant to what this
          // test checks.
          nextUpcomingAppointmentProvider.overrideWith(
            (ref, patientId) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DashboardPage(),
          ),
        ),
      );
      await tester.pump();

      // The goals fetch is still in flight (the completer hasn't fired).
      // This is the exact case that lied before the fix.
      expect(
        find.text(_noGoalsText),
        findsNothing,
        reason:
            'a goals fetch that has not settled yet must not be rendered '
            'as "no goals" — it is unknown, not empty',
      );
      expect(find.byType(WellnessGoalRow), findsNothing);

      // Now let it settle with a real, non-empty goal list.
      goalsCompleter.complete([_goal]);
      await tester.pumpAndSettle();

      expect(find.text(_noGoalsText), findsNothing);
      expect(find.byType(WellnessGoalRow), findsOneWidget);
    },
  );
}
