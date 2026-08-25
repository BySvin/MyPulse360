import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/role_nav_config.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../patient/domain/entities/patient_profile.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    await _handlePostAuth();
  }

  Future<void> _handlePostAuth() async {
    final state = ref.read(authControllerProvider);
    if (state is! AuthAuthenticated || !mounted) return;
    final user = state.user;
    if (user.mustChangePassword) {
      context.go(RoutePaths.forcePasswordChange);
      return;
    }
    // Await the settled profile rather than sampling whatever the
    // FutureProvider currently holds — see splash_page.dart for why.
    if (user.role.name == 'patient') {
      // Unlike splash_page.dart there is nowhere to "fall back" to — the
      // user is already on the login screen. This is deliberately not
      // routed through authControllerProvider's AuthError: login itself
      // succeeded, this is a separate failure (the onboarding check), and
      // misreporting it as an auth failure would be wrong for every other
      // listener of that state (the router included). Surface it the same
      // way the AuthError listener below does, directly.
      PatientProfile? profile;
      try {
        profile = await ref.read(patientProfileProvider(user.id).future);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "Couldn't load your profile. Please try signing in again.",
              ),
            ),
          );
        return;
      }
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
    final colors = context.colors;
    final authState = ref.watch(authControllerProvider);
    final loading = authState is AuthLoading;

    ref.listen(authControllerProvider, (prev, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.success, colors.info],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to continue to MyPulse360',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 28),
              AppTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Sign In',
                onPressed: _submit,
                loading: loading,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.push(RoutePaths.signUp),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
