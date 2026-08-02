import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
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
class ForcePasswordChangePage extends ConsumerStatefulWidget {
  const ForcePasswordChangePage({super.key});

  @override
  ConsumerState<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends ConsumerState<ForcePasswordChangePage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? get _passwordError => _touched ? Validators.password(_passwordController.text) : null;
  String? get _confirmError {
    if (!_touched) return null;
    if (_confirmController.text != _passwordController.text) return "Passwords don't match";
    return null;
  }

  bool get _isFormValid =>
      Validators.password(_passwordController.text) == null &&
      _confirmController.text == _passwordController.text;

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (!_isFormValid) return;
    await ref.read(authControllerProvider.notifier).changePassword(newPassword: _passwordController.text);
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
      appBar: const LargeTitleAppBar(title: 'Set a new password'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This account was created with a temporary password. Choose your own before continuing.',
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
            const SizedBox(height: 28),
            PrimaryButton(label: 'Set password & continue', onPressed: _submit, loading: loading),
          ],
        ),
      ),
    );
  }
}
