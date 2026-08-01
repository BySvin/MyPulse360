import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../domain/entities/prescription.dart';
import 'prescription_item_row.dart';

class PrescriptionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.medication_outlined, size: 20, color: colors.patientAccentText),
              StatusBadge(label: prescription.status.label, tone: _tone),
            ],
          ),
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
