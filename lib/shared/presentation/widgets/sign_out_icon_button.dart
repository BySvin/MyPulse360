import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/router/route_paths.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text("You'll need to sign in again to access your account."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go(RoutePaths.login);
  }
}

/// Minimal sign-out affordance for roles (doctor, pharmacist) that don't
/// have a dedicated profile/settings screen in this design.
class SignOutIconButton extends ConsumerWidget {
  const SignOutIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => confirmLogout(context, ref),
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'Sign out',
    );
  }
}
