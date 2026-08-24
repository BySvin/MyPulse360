import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/role_nav_config.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// P1 — Welcome / Splash. Shows briefly, then routes based on auth state.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Minimum time the brand screen stays up, so it reads as intentional
    // rather than a flicker.
    await Future.delayed(const Duration(milliseconds: 900));

    // The session restore may still be running. Waiting for it is the whole
    // point: treating "not yet authenticated" as "not signed in" is what
    // sends an already-signed-in user to the login screen. A short poll is
    // deliberate here — the window is sub-second, and a listener subscription
    // in initState needs disposal handling this does not otherwise need.
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted &&
        ref.read(authControllerProvider) is AuthLoading &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) {
      context.go(RoutePaths.login);
      return;
    }
    final user = authState.user;
    if (user.mustChangePassword) {
      context.go(RoutePaths.forcePasswordChange);
      return;
    }
    // Await the settled profile rather than sampling whatever the FutureProvider
    // currently holds — a still-loading profile is not "no profile", and
    // treating it as one is what sends an already-onboarded patient back
    // through onboarding on every launch.
    if (user.role.name == 'patient') {
      final profile = await ref.read(patientProfileProvider(user.id).future);
      if (!mounted) return;
      if (profile == null) {
        context.go(RoutePaths.onboardingWellnessGoals);
        return;
      }
    }
    context.go(kRoleNavConfig[user.role]!.rootPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [AppColors.primaryGreen, AppColors.teal],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'MyPulse360',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your health journey, in your pocket',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
