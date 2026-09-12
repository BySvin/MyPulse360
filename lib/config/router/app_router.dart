import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/pages/appointment_detail_page.dart';
import '../../features/appointments/presentation/pages/appointments_list_page.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/pages/force_password_change_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/chatbot/presentation/pages/health_assistant_page.dart';
import '../../features/doctor/presentation/pages/doctor_dashboard_page.dart';
import '../../features/doctor/presentation/pages/patient_history_page.dart';
import '../../features/doctor/presentation/pages/staff_management_page.dart';
import '../../features/health_dashboard/domain/entities/metric_type.dart';
import '../../features/health_dashboard/presentation/pages/dashboard_page.dart';
import '../../features/health_dashboard/presentation/pages/health_metric_detail_page.dart';
import '../../features/health_dashboard/presentation/pages/health_overview_page.dart';
import '../../features/patient/presentation/pages/health_profile_setup_page.dart';
import '../../features/patient/presentation/pages/onboarding_emergency_contact_page.dart';
import '../../features/patient/presentation/pages/onboarding_healthcare_preferences_page.dart';
import '../../features/patient/presentation/pages/onboarding_welcome_page.dart';
import '../../features/patient/presentation/pages/onboarding_wellness_goals_page.dart';
import '../../features/patient/presentation/pages/profile_page.dart';
import '../../features/patient/presentation/providers/patient_providers.dart';
import '../../features/pharmacist/presentation/pages/create_prescription_page.dart';
import '../../features/pharmacist/presentation/pages/pharmacist_dashboard_page.dart';
import '../../features/pharmacist/presentation/pages/pharmacist_prescriptions_page.dart';
import '../../features/pharmacist/presentation/pages/prescription_verification_page.dart';
import '../../features/prescriptions/presentation/pages/prescriptions_list_page.dart';
import '../../features/scheduling/presentation/pages/apply_leave_page.dart';
import '../../shared/presentation/widgets/app_shell_scaffold.dart';
import '../../shared/presentation/widgets/clinician_app_shell.dart';
import '../theme/app_theme.dart';
import 'role_nav_config.dart';
import 'route_paths.dart';

/// Bridges Riverpod state changes into a [Listenable] so [GoRouter] rebuilds
/// (and re-runs `redirect`) whenever auth or onboarding state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(patientDataRevisionProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);

      // Authentication is still being restored.
      if (authState is AuthInitial || authState is AuthLoading) {
        return RoutePaths.splash;
      }

      // User is not authenticated.
      if (authState is! AuthAuthenticated) {
        if (state.matchedLocation == RoutePaths.login) {
          return null;
        }

        return RoutePaths.login;
      }

      final user = authState.user;

      // Only patients need the patient-profile onboarding check.
      if (user.role == UserRole.patient) {
        final profileAsync = ref.read(patientProfileProvider(user.id));

        // Profile is still being fetched.
        if (profileAsync.isLoading) {
          return null;
        }

        // IMPORTANT:
        // A failed profile fetch is NOT the same as "no profile".
        // Do not redirect an authenticated patient to onboarding.
        if (profileAsync.hasError) {
          return null;
        }

        final profile = profileAsync.valueOrNull;

        // Profile doesn't exist -> patient hasn't completed onboarding.
        if (profile == null) {
          if (state.matchedLocation == RoutePaths.onboardingWelcome) {
            return null;
          }

          return RoutePaths.onboardingWelcome;
        }

        // Patient has a profile, so don't send them back to onboarding.
        if (state.matchedLocation == RoutePaths.onboardingWelcome) {
          return RoutePaths.home;
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: RoutePaths.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: RoutePaths.signUp, builder: (_, _) => const SignUpPage()),
      GoRoute(
        path: RoutePaths.forcePasswordChange,
        builder: (_, _) => const ForcePasswordChangePage(),
      ),
      GoRoute(
        path: RoutePaths.onboardingWelcome,
        builder: (_, _) => const OnboardingWelcomePage(),
      ),
      GoRoute(
        path: RoutePaths.onboardingEmergencyContact,
        builder: (_, _) => const OnboardingEmergencyContactPage(),
      ),
      GoRoute(
        path: RoutePaths.onboardingHealthcarePreferences,
        builder: (_, _) => const OnboardingHealthcarePreferencesPage(),
      ),
      GoRoute(
        path: RoutePaths.onboardingWellnessGoals,
        builder: (_, _) => const OnboardingWellnessGoalsPage(),
      ),
      GoRoute(
        path: RoutePaths.onboardingHealthProfile,
        builder: (_, _) => const HealthProfileSetupPage(),
      ),
      GoRoute(
        path: RoutePaths.patientHealthMetricDetail,
        builder: (_, state) {
          final typeName = state.pathParameters['type'];
          final type = MetricType.values.firstWhere(
            (t) => t.name == typeName,
            orElse: () => MetricType.weight,
          );
          return HealthMetricDetailPage(type: type);
        },
      ),
      GoRoute(
        path: RoutePaths.patientHealthOverview,
        builder: (_, _) => const HealthOverviewPage(),
      ),
      GoRoute(
        path: RoutePaths.patientAppointmentDetail,
        builder: (_, state) => AppointmentDetailPage(
          appointmentId: state.pathParameters['appointmentId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShellScaffold(
          navigationShell: shell,
          items: kRoleNavConfig[UserRole.patient]!.items,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.patientDashboard,
                builder: (_, _) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.patientAppointments,
                builder: (_, _) => const AppointmentsListPage(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.patientAssistant,
                builder: (_, _) => const HealthAssistantPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.patientPrescriptions,
                builder: (_, _) => const PrescriptionsListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.patientProfile,
                builder: (_, _) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.doctorPatientHistory,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: PatientHistoryPage(
            patientId: state.pathParameters['patientId']!,
            appointmentId: state.uri.queryParameters['appointmentId'],
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ClinicianAppShell(
          navigationShell: shell,
          items: kRoleNavConfig[UserRole.doctor]!.items,
          accentColor: context.colors.clinicianAccent,
          userName: ref.read(currentUserProvider)?.fullName ?? 'Doctor',
          roleLabel: 'Doctor',
          avatarUrl: ref.read(currentUserProvider)?.avatarUrl,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.doctorDashboard,
                builder: (_, _) => const DoctorDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.doctorStaffManagement,
                builder: (_, _) => const StaffManagementPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.doctorApplyLeave,
                builder: (_, _) => const ApplyLeavePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.pharmacistVerify,
        builder: (_, state) => PrescriptionVerificationPage(
          prescriptionId: state.pathParameters['prescriptionId']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.pharmacistCreatePrescription,
        builder: (_, state) => CreatePrescriptionPage(
          consultationId: state.pathParameters['consultationId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ClinicianAppShell(
          navigationShell: shell,
          items: kRoleNavConfig[UserRole.pharmacist]!.items,
          accentColor: context.colors.clinicianAccent,
          userName:
              ref.read(currentUserProvider)?.fullName ?? 'Clinic Assistant',
          roleLabel: 'Clinic Assistant',
          avatarUrl: ref.read(currentUserProvider)?.avatarUrl,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.pharmacistDashboard,
                builder: (_, _) => const PharmacistDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.pharmacistPrescriptions,
                builder: (_, _) => const PharmacistPrescriptionsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
