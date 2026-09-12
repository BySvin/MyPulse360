import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/patient_providers.dart';

class AccountDeletionPage extends ConsumerStatefulWidget {
  const AccountDeletionPage({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends ConsumerState<AccountDeletionPage> {
  final _confirmController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_confirmController.text.trim().toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type DELETE to confirm.')),
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await ref.read(patientRepositoryProvider).deleteAccount(widget.patientId);
      if (!mounted) return;
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go(RoutePaths.login);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.warning_rounded, size: 64, color: colors.danger),
            const SizedBox(height: 24),
            Text(
              'This action cannot be undone.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.danger,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You are about to permanently delete your account and all associated health data, appointments, and records. Once deleted, this data cannot be recovered.',
              style: TextStyle(fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            const Text(
              'Please type "DELETE" to confirm:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              decoration: InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isDeleting || _confirmController.text.trim().toUpperCase() != 'DELETE'
                  ? null
                  : _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Permanently Delete Account'),
            ),
          ],
        ),
      ),
    );
  }
}
