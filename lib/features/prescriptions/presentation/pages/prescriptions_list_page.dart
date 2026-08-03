import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/prescriptions_providers.dart';
import '../widgets/prescription_card.dart';
import 'scan_prescription_page.dart';

/// P7 — Prescriptions: active, expiring, and expired cards.
class PrescriptionsListPage extends ConsumerWidget {
  const PrescriptionsListPage({super.key});

  void _scan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanPrescriptionPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final prescriptions = ref.watch(patientPrescriptionsProvider(user.id));

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Prescriptions',
        showBack: false,
        actions: [
          IconButton(
            onPressed: () => _scan(context),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan prescription',
          ),
        ],
      ),
      body: prescriptions.isEmpty
          ? EmptyStateView(
              title: 'No prescriptions yet',
              message: 'Prescriptions from your doctor will show up here — or scan a paper prescription to add it.',
              icon: Icons.medication_outlined,
              actionLabel: 'Scan Prescription',
              onAction: () => _scan(context),
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
