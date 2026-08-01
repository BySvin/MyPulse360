import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/validators.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/password_strength_hint.dart';
import '../widgets/role_select_field.dart';

/// P2 — Sign Up, with inline per-field validation.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.patient;
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
          role: _role,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state is AuthAuthenticated) {
      if (_role == UserRole.patient) {
        context.go(RoutePaths.onboardingWellnessGoals);
      } else {
        context.go(RoutePaths.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 20),
            RoleSelectField(value: _role, onChanged: (r) => setState(() => _role = r)),
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
