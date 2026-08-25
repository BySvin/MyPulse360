// Guards the fix in splash_page.dart: _navigateNext must wait for an
// in-flight session restore (AuthLoading) to settle before deciding where
// to send the user, instead of assuming a fixed 900ms delay is enough. The
// old fixed-timer version would have sent an already-signed-in user to
// /login the moment AuthLoading was still the state at 900ms — this test's
// first assertion is exactly the one that would have failed against that
// version.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mypulse360/config/router/route_paths.dart';
import 'package:mypulse360/features/auth/domain/entities/app_user.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/features/auth/presentation/pages/splash_page.dart';
import 'package:mypulse360/features/auth/presentation/providers/auth_providers.dart';
import 'package:mypulse360/features/auth/presentation/state/auth_state.dart';
import 'package:mypulse360/features/patient/domain/entities/patient_profile.dart';
import 'package:mypulse360/features/patient/presentation/providers/patient_providers.dart';

/// A controllable stand-in for [AuthController]. Overriding `build()` means
/// the real controller's Hive/Supabase reads never run — the test drives
/// [AuthState] directly via [emit].
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void emit(AuthState next) => state = next;
}

const _patientUser = AppUser(
  id: 'patient-1',
  email: 'patient@example.com',
  fullName: 'Pat Ient',
  role: UserRole.patient,
  clinicId: 'clinic-1',
);

const _onboardedProfile = PatientProfile(
  id: 'patient-1',
  heightCm: 170,
  weightKg: 70,
  allergies: [],
  chronicConditions: [],
  currentMedications: [],
  assignedDoctorId: 'user-dr-ahmed',
);

void main() {
  testWidgets(
    'splash holds while the restore is loading and only navigates once it settles',
    (tester) async {
      final fakeController = _FakeAuthController(const AuthLoading());

      final router = GoRouter(
        initialLocation: RoutePaths.splash,
        routes: [
          GoRoute(
            path: RoutePaths.splash,
            builder: (_, _) => const SplashPage(),
          ),
          GoRoute(
            path: RoutePaths.login,
            builder: (_, _) => const Scaffold(body: Text('LOGIN')),
          ),
          GoRoute(
            path: RoutePaths.patientDashboard,
            builder: (_, _) => const Scaffold(body: Text('DASHBOARD')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => fakeController),
            // Avoids depending on the mock patient repository/Hive for a
            // detail (onboarding status) unrelated to what this test checks.
            // splash_page.dart awaits patientProfileProvider(id).future to
            // decide onboarding status, so it must resolve to a non-null
            // profile here or the fake patient gets routed to onboarding
            // instead of the dashboard, which is not what this test guards.
            patientProfileProvider.overrideWith(
              (ref, patientId) async => _onboardedProfile,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // Elapse well past the 900ms minimum brand delay while the restore is
      // still AuthLoading. This is the case the fixed-timer bug got wrong:
      // it would have called context.go(RoutePaths.login) right here.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 200));

      expect(router.state.matchedLocation, RoutePaths.splash);
      expect(find.text('LOGIN'), findsNothing);
      expect(find.text('DASHBOARD'), findsNothing);

      // The restore settles.
      fakeController.emit(const AuthAuthenticated(_patientUser));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(router.state.matchedLocation, RoutePaths.patientDashboard);
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
    },
  );
}
