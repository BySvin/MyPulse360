import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/my_schedule_view.dart';

/// Pharmacist's Schedule tab — just the personal view, no team-wide admin
/// capability (mirrors the doctor-as-admin split used by Staff Management).
class MySchedulePage extends ConsumerWidget {
  const MySchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule'), centerTitle: false),
      body: SafeArea(child: MyScheduleView(staffId: user.id)),
    );
  }
}
