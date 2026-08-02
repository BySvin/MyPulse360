import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../patient/domain/entities/patient_profile.dart';

/// BMI-at-a-glance card for the dashboard, derived from the patient's
/// height/weight — the two fields Health Profile Setup always requires.
class HealthSnapshotCard extends StatelessWidget {
  const HealthSnapshotCard({super.key, required this.profile});

  final PatientProfile profile;

  StatusTone get _tone => switch (profile.bmiCategory) {
        'Healthy weight' => StatusTone.success,
        'Underweight' || 'Overweight' => StatusTone.warning,
        _ => StatusTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.bmi.toStringAsFixed(1),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text('BMI', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(label: profile.bmiCategory, tone: _tone),
                const SizedBox(height: 6),
                Text(
                  '${profile.heightCm.toStringAsFixed(0)} cm · ${profile.weightKg.toStringAsFixed(1)} kg',
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
