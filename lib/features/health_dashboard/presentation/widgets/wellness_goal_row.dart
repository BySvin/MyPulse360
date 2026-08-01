import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/progress_bar_row.dart';
import '../../../patient/domain/entities/wellness_goal.dart';
import '../../../patient/presentation/widgets/goal_picker_card.dart';

class WellnessGoalRow extends StatelessWidget {
  const WellnessGoalRow({super.key, required this.goal});

  final WellnessGoal goal;

  String get _statusLabel => switch (goal.status) {
        GoalStatus.onTrack => 'On track',
        GoalStatus.atRisk => 'At risk',
        GoalStatus.excellent => 'Excellent',
        GoalStatus.behind => 'Behind',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = switch (goal.status) {
      GoalStatus.onTrack => colors.successText,
      GoalStatus.excellent => colors.successText,
      GoalStatus.atRisk => colors.warningText,
      GoalStatus.behind => colors.danger,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: colors.info.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(goalTypeIcon(goal.type), size: 17, color: colors.infoText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(goal.name, style: Theme.of(context).textTheme.titleSmall),
                    Text(_statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${goal.currentValue.toStringAsFixed(goal.currentValue == goal.currentValue.roundToDouble() ? 0 : 1)} of ${goal.targetValue.toStringAsFixed(goal.targetValue == goal.targetValue.roundToDouble() ? 0 : 1)} ${goal.unit}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                const SizedBox(height: 6),
                ProgressBarRow(progress: goal.progress, color: colors.info),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
