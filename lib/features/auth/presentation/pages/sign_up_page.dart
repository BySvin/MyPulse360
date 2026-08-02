import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/password_strength_hint.dart';

/// P2 — Sign Up. Patient self-registration only: there is no role picker
/// here by design, so this form can never create a doctor/pharmacist
/// account. Staff accounts are provisioned by a doctor in the web
/// dashboard's Staff Management screen instead.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _touchedName = false;
  bool _touchedEmail = false;
  bool _touchedPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _nameError =>
      _touchedName ? Validators.required(_nameController.text, field: 'Full name') : null;
  String? get _emailError => _touchedEmail ? Validators.email(_emailController.text) : null;
  String? get _passwordError => _touchedPassword ? Validators.password(_passwordController.text) : null;

  bool get _isFormValid =>
      Validators.required(_nameController.text, field: 'Full name') == null &&
      Validators.email(_emailController.text) == null &&
      Validators.password(_passwordController.text) == null;

  Future<void> _submit() async {
    setState(() {
      _touchedName = true;
      _touchedEmail = true;
      _touchedPassword = true;
    });
    if (!_isFormValid) return;
    await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state is AuthAuthenticated) {
      context.go(RoutePaths.onboardingWellnessGoals);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const _WebSignUpBlocked();

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
      appBar: const LargeTitleAppBar(title: 'Create Account'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Full name',
              controller: _nameController,
              errorText: _nameError,
              isValid: _touchedName && _nameError == null && _nameController.text.isNotEmpty,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              isValid: _touchedEmail && _emailError == null && _emailController.text.isNotEmpty,
              onChanged: (_) => setState(() => _touchedEmail = true),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
              errorText: _passwordError,
              isValid: _touchedPassword && _passwordError == null,
              onChanged: (_) => setState(() {}),
            ),
            PasswordStrengthHint(password: _passwordController.text),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Create Account',
              onPressed: _isFormValid ? _submit : null,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }
}

class _WebSignUpBlocked extends StatelessWidget {
  const _WebSignUpBlocked();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Create Account'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phone_iphone_rounded, size: 40, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text('Patient registration is mobile-only', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create your MyPulse360 account from the mobile app. This web dashboard is for clinic staff — '
              'doctor and pharmacist accounts are set up by your clinic administrator.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Back to sign in', onPressed: () => context.go(RoutePaths.login)),
          ],
        ),
      ),
    );
  }
}
