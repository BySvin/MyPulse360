import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../../../prescriptions/presentation/widgets/prescription_item_row.dart';
import '../providers/inventory_providers.dart';
import '../providers/pharmacist_providers.dart';
import '../widgets/dispense_action_bar.dart';
import '../widgets/verification_checklist.dart';

/// F2 — Prescription verification: every check resolved before Dispense
/// becomes reachable.
class PrescriptionVerificationPage extends ConsumerStatefulWidget {
  const PrescriptionVerificationPage({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  ConsumerState<PrescriptionVerificationPage> createState() => _PrescriptionVerificationPageState();
}

class _PrescriptionVerificationPageState extends ConsumerState<PrescriptionVerificationPage> {
  final Set<int> _checked = {};
  bool _dispensing = false;

  Future<void> _dispense(Prescription prescription) async {
    setState(() => _dispensing = true);
    final user = ref.read(currentUserProvider);
    final locationId = user == null
        ? MockIds.defaultClinicId
        : ref.read(pharmacistProfileProvider(user.id))?.clinicId ?? MockIds.defaultClinicId;
    final inventoryRepository = ref.read(inventoryRepositoryProvider);
    for (final item in prescription.items) {
      await inventoryRepository.deductForDispense(
        locationId: locationId,
        medicationName: item.medicationName,
        strength: item.strength,
        quantity: item.quantity,
      );
    }
    ref.read(inventoryRevisionProvider.notifier).state++;
    await ref
        .read(prescriptionsRepositoryProvider)
        .updateStatus(prescription.id, PrescriptionStatus.dispensed);
    ref.read(prescriptionsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _dispensing = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final queue = ref.watch(pharmacyQueueProvider(user.id));
    final matches = queue.where((p) => p.id == widget.prescriptionId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Prescription not found')));
    }
    final prescription = matches.first;
    final patient = ref.watch(userProfileProvider(prescription.patientId)).valueOrNull;
    final allChecked = _checked.length == kVerificationSteps.length;

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Verify Prescription'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Row(
                children: [
                  AvatarWidget(name: patient?.fullName ?? 'Patient', color: colors.clinicianAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient?.fullName ?? 'Patient', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          'Issued ${prescription.issuedDate.toLocal().toString().split(' ').first}',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Medications', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  for (final item in prescription.items) PrescriptionItemRow(item: item),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Verification checklist', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            VerificationChecklist(
              checked: _checked,
              onChanged: (i) => setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DispenseActionBar(
        enabled: allChecked,
        onDispense: () => _dispense(prescription),
        loading: _dispensing,
      ),
    );
  }
}
