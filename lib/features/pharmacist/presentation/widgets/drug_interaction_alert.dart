import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../prescriptions/domain/entities/drug_interaction.dart';

class DrugInteractionAlert extends StatelessWidget {
  const DrugInteractionAlert({super.key, required this.interactions});

  final List<DrugInteraction> interactions;

  @override
  Widget build(BuildContext context) {
    if (interactions.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.08),
        border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_outlined, size: 16, color: colors.danger),
              const SizedBox(width: 6),
              Text(
                'Interaction check',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.danger),
              ),
            ],
          ),
          for (final i in interactions) ...[
            const SizedBox(height: 8),
            Text(
              '${_cap(i.medicationA)} + ${_cap(i.medicationB)} (${i.severity.name})',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            Text(i.description, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
