import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/validators.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';
import '../widgets/password_strength_hint.dart';

/// Forced gate for any account created with a temp password
/// (`AppUser.mustChangePassword`). The router redirects here regardless of
/// destination until a new password is set — see `app_router.dart`.
///
/// For staff accounts (doctor/pharmacist), this page also prompts the staff
/// member to replace their temporary email with their permanent email address.
/// The email is updated via the `update-staff-email` Edge Function so the
/// auth identity and the application profile are both updated atomically.
class ForcePasswordChangePage extends ConsumerStatefulWidget {
  const ForcePasswordChangePage({super.key});

  @override
  ConsumerState<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends ConsumerState<ForcePasswordChangePage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailController = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? get _passwordError => _touched ? Validators.password(_passwordController.text) : null;
  String? get _confirmError {
    if (!_touched) return null;
    if (_confirmController.text != _passwordController.text) return "Passwords don't match";
    return null;
  }

  String? get _emailError {
    if (!_touched || _emailController.text.isEmpty) return null;
    return Validators.email(_emailController.text);
  }

  bool get _isFormValid =>
      Validators.password(_passwordController.text) == null &&
      _confirmController.text == _passwordController.text &&
      (_emailController.text.isEmpty || Validators.email(_emailController.text) == null);

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (!_isFormValid) return;
    await ref
        .read(authControllerProvider.notifier)
        .changePassword(newPassword: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authState = ref.watch(authControllerProvider);
    final currentUser = ref.watch(currentUserProvider);
    final loading = authState is AuthLoading;
    final isStaff = currentUser?.role == UserRole.doctor || currentUser?.role == UserRole.pharmacist;

    ref.listen(authControllerProvider, (prev, next) async {
      if (next is AuthError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.message)));
      } else if (next is AuthAuthenticated && prev is AuthLoading) {
        // Password has been changed. Now update the email if it differs.
        final newEmail = _emailController.text.trim();
        if (isStaff && newEmail.isNotEmpty && newEmail != currentUser?.email) {
          await ref.read(authControllerProvider.notifier).updateEmail(newEmail: newEmail);
        }
      }
    });

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Set a new password'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStaff
                  ? 'Your account was created with a temporary email and password. '
                      'Set your permanent credentials before continuing.'
                  : 'This account was created with a temporary password. '
                      'Choose your own before continuing.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'New password',
              controller: _passwordController,
              obscureText: true,
              errorText: _passwordError,
              isValid: _touched && _passwordError == null,
              onChanged: (_) => setState(() {}),
            ),
            PasswordStrengthHint(password: _passwordController.text),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirm new password',
              controller: _confirmController,
              obscureText: true,
              errorText: _confirmError,
              isValid: _touched && _confirmError == null && _confirmController.text.isNotEmpty,
              onChanged: (_) => setState(() {}),
            ),
            if (isStaff) ...[
              const SizedBox(height: 20),
              AppTextField(
                label: 'Your permanent email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                isValid: _touched && _emailError == null && _emailController.text.isNotEmpty,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the email you want to use permanently. '
                'You can change this later from your profile.',
                style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.4),
              ),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: isStaff ? 'Set credentials & continue' : 'Set password & continue',
              onPressed: _submit,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }
}
