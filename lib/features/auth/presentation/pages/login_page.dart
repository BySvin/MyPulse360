import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/role_nav_config.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
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
        .login(email: _emailController.text, password: _passwordController.text);
    _handlePostAuth();
  }

  Future<void> _quickSignIn(String email) async {
    _emailController.text = email;
    await ref.read(authControllerProvider.notifier).login(email: email, password: 'demo');
    _handlePostAuth();
  }

  void _handlePostAuth() {
    final state = ref.read(authControllerProvider);
    if (state is! AuthAuthenticated || !mounted) return;
    final user = state.user;
    if (user.role.name == 'patient' && !ref.read(onboardingCompleteProvider(user.id))) {
      context.go(RoutePaths.onboardingWellnessGoals);
      return;
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
                  gradient: LinearGradient(colors: [colors.success, colors.info]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
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
              PrimaryButton(label: 'Sign In', onPressed: _submit, loading: loading),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.push(RoutePaths.signUp),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Divider(color: colors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Quick demo sign-in', style: TextStyle(fontSize: 11, color: colors.textTertiary)),
                  ),
                  Expanded(child: Divider(color: colors.border)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PersonaChip(label: 'Sarah (Patient)', onTap: () => _quickSignIn('sarah@example.com')),
                  _PersonaChip(label: 'Dr. Ahmed (Doctor)', onTap: () => _quickSignIn('dr.ahmed@mypulse360.clinic')),
                  _PersonaChip(label: 'Fatima (Pharmacist)', onTap: () => _quickSignIn('fatima@mypulse360.clinic')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaChip extends StatelessWidget {
  const _PersonaChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: colors.surfaceMuted,
      side: BorderSide(color: colors.border),
      onPressed: onTap,
    );
  }
}
