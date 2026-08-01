import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/prescriptions_providers.dart';
import '../widgets/prescription_card.dart';

/// P7 — Prescriptions: active, expiring, and expired cards.
class PrescriptionsListPage extends ConsumerWidget {
  const PrescriptionsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final prescriptions = ref.watch(patientPrescriptionsProvider(user.id));

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Prescriptions', showBack: false),
      body: prescriptions.isEmpty
          ? const EmptyStateView(
              title: 'No prescriptions yet',
              message: 'Prescriptions from your doctor will show up here.',
              icon: Icons.medication_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: prescriptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => PrescriptionCard(prescription: prescriptions[i]),
            ),
    );
  }
}
