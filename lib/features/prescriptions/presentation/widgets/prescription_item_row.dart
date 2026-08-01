import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../domain/entities/prescription_item.dart';

class PrescriptionItemRow extends StatelessWidget {
  const PrescriptionItemRow({super.key, required this.item});

  final PrescriptionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: colors.patientAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.medicationName} ${item.strength}', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${item.frequency} · ${item.durationDays} days · ${item.instructions}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
