import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../domain/entities/wellness_goal.dart';

IconData goalTypeIcon(WellnessGoalType type) => switch (type) {
      WellnessGoalType.exercise => Icons.directions_walk,
      WellnessGoalType.hydration => Icons.local_drink_outlined,
      WellnessGoalType.sleep => Icons.bedtime_outlined,
      WellnessGoalType.diet => Icons.restaurant_outlined,
      WellnessGoalType.custom => Icons.track_changes_outlined,
    };

class GoalPickerCard extends StatelessWidget {
  const GoalPickerCard({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final WellnessGoalType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? colors.patientAccent.withValues(alpha: 0.08) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: selected ? colors.patientAccent : colors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(goalTypeIcon(type), size: 19, color: colors.infoText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(type.label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? colors.patientAccent : colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
