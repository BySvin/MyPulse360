import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/validators.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/password_strength_hint.dart';
import '../providers/staff_management_providers.dart';

/// Doctor-only account provisioning: creates a Doctor or Pharmacist account
/// with a temp password. There is no self-signup path to a staff role —
/// this sheet is the only way one gets created.
Future<void> showAddStaffSheet(BuildContext context, WidgetRef ref, String clinicId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddStaffSheet(clinicId: clinicId),
  );
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet({required this.clinicId});

  final String clinicId;

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.pharmacist;
  bool _saving = false;
  String? _error;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      Validators.email(_emailController.text) == null &&
      Validators.password(_passwordController.text) == null;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).createStaffAccount(
            email: _emailController.text.trim(),
            tempPassword: _passwordController.text,
            fullName: _nameController.text.trim(),
            role: _role,
            clinicId: widget.clinicId,
          );
      ref.read(staffAccountsRevisionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Add Staff Account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Creates the account with a temporary password. They’ll be required to set their own on first sign-in.',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (final r in [UserRole.doctor, UserRole.pharmacist]) ...[
                      Expanded(
                        child: ChoiceChip(
                          label: Text(r.label, style: const TextStyle(fontSize: 12)),
                          selected: _role == r,
                          onSelected: (_) => setState(() => _role = r),
                          selectedColor: colors.clinicianAccent,
                          labelStyle: TextStyle(color: _role == r ? Colors.white : colors.textPrimary),
                          backgroundColor: Theme.of(context).cardTheme.color,
                          side: BorderSide(color: colors.border),
                        ),
                      ),
                      if (r != UserRole.pharmacist) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Work email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                PasswordStrengthHint(password: _passwordController.text),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: colors.danger, fontSize: 12)),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Add Staff Account',
                  onPressed: _canSave ? _save : null,
                  loading: _saving,
                  color: colors.clinicianAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
