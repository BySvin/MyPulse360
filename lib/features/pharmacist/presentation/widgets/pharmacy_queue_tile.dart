import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../prescriptions/domain/entities/prescription.dart';

/// Wait-time badge shared by [PharmacyQueueTile] (mobile card) and the
/// desktop queue table, so the "30 min" amber rule lives in one place.
class QueueWait {
  const QueueWait(this.label, this.tone);

  final String label;
  final StatusTone tone;

  factory QueueWait.forPrescription(Prescription prescription) {
    final wait = DateTime.now().difference(prescription.issuedDate);
    final mins = wait.inMinutes;
    final label = mins < 60 ? '$mins min wait' : '${wait.inHours}h ${mins % 60}m wait';
    return QueueWait(label, mins > 30 ? StatusTone.warning : StatusTone.neutral);
  }
}

class PharmacyQueueTile extends StatelessWidget {
  const PharmacyQueueTile({
    super.key,
    required this.prescription,
    required this.patientName,
    this.onTap,
  });

  final Prescription prescription;
  final String patientName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final medNames = prescription.items.map((i) => i.medicationName).join(', ');
    final wait = QueueWait.forPrescription(prescription);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AvatarWidget(name: patientName, color: colors.clinicianAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(medNames, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
          StatusBadge(label: wait.label, tone: wait.tone),
        ],
      ),
    );
  }
}
