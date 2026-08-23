import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import 'prescription_item_row.dart';

class PrescriptionCard extends ConsumerWidget {
  const PrescriptionCard({super.key, required this.prescription});

  final Prescription prescription;

  StatusTone get _tone => switch (prescription.status) {
        PrescriptionStatus.active => StatusTone.success,
        PrescriptionStatus.expiring => StatusTone.warning,
        PrescriptionStatus.expired => StatusTone.danger,
        PrescriptionStatus.dispensed => StatusTone.info,
        PrescriptionStatus.cancelled => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isScanned = prescription.source == PrescriptionSource.scannedExternal;
    final prescriberName = isScanned
        ? (prescription.externalDoctorName ?? 'Unknown prescriber')
        : ref.watch(userProfileProvider(prescription.doctorId)).valueOrNull?.fullName;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.medication_outlined, size: 20, color: colors.patientAccentText),
              Row(
                children: [
                  if (isScanned) ...[
                    const StatusBadge(label: 'Scanned', tone: StatusTone.neutral),
                    const SizedBox(width: 6),
                  ],
                  StatusBadge(label: prescription.status.label, tone: _tone),
                ],
              ),
            ],
          ),
          if (prescriberName != null) ...[
            const SizedBox(height: 8),
            Text(
              isScanned ? prescriberName : 'Prescribed by $prescriberName',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ],
          const Divider(height: 20),
          for (final item in prescription.items) PrescriptionItemRow(item: item),
          const SizedBox(height: 4),
          Text(
            prescription.status == PrescriptionStatus.expired
                ? 'Expired ${prescription.expiryDate.toLocal().toString().split(' ').first}'
                : 'Valid until ${prescription.expiryDate.toLocal().toString().split(' ').first}',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
