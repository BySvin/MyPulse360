// Guards the fix in app_router.dart's redirect: an onboarded patient whose
// profile fetch *fails* (not just loads) must not be force-redirected into
// the onboarding flow. Before the fix, the redirect guard checked
// `profileAsync.isLoading` only; an errored fetch is neither loading nor a
// settled value, so `valueOrNull` collapsed to null, `onboarded` computed to
// false, and the router bounced the patient to /onboarding/welcome — even
// though splash_page.dart had already (correctly) sent them to /login.
//
// This test exercises the real `appRouterProvider`, not a hand-copied
// redirect predicate, so a regression in app_router.dart's actual logic is
// what would turn this test red.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mypulse360/config/router/app_router.dart';
import 'package:mypulse360/config/router/route_paths.dart';
import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/auth/domain/entities/app_user.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/features/auth/presentation/providers/auth_providers.dart';
import 'package:mypulse360/features/auth/presentation/state/auth_state.dart';
import 'package:mypulse360/features/patient/presentation/providers/patient_providers.dart';

/// A controllable stand-in for [AuthController] that starts already
/// authenticated, so no session-restore delay is involved.
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

void main() {
  testWidgets(
    'an onboarded patient whose profile fetch errors is not bounced into '
    'onboarding',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(const AuthAuthenticated(_patientUser)),
          ),
          // Every fetch of this patient's profile fails — a dropped
          // connection, a 500, anything. It must settle to AsyncError, not
          // hang, so the redirect's `hasValue` gate has something to react
          // to.
          patientProfileProvider.overrideWith(
            (ref, patientId) async => throw Exception('network down'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );

      // SplashPage keeps the brand screen up for a minimum 900ms before it
      // even looks at the profile, and schedules that as a one-shot timer.
      // Elapse past it, let the errored fetch settle, and let the redirect
      // (re)mount the login screen.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(router.state.matchedLocation, RoutePaths.login);
    },
  );
}
