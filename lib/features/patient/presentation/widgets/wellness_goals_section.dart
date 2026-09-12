import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/grouped_list.dart';
import '../../../../shared/presentation/widgets/grouped_list_tile.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../domain/entities/wellness_goal.dart';
import '../providers/patient_providers.dart';
import 'goal_picker_card.dart';

/// Wellness Goals section of the profile: each goal is removable, and a sheet
/// offers the starter habits the patient isn't already tracking. Deleting and
/// adding both bump `patientDataRevisionProvider` so the list re-reads.
class WellnessGoalsSection extends ConsumerWidget {
  const WellnessGoalsSection({
    super.key,
    required this.patientId,
    required this.goals,
  });

  final String patientId;
  final List<WellnessGoal> goals;

  String _f(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WellnessGoal goal,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove goal?',
      message: 'This goal will be removed from your wellness tracking.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(patientRepositoryProvider).deleteGoal(patientId, goal.id);
    ref.read(patientDataRevisionProvider.notifier).state++;
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final owned = goals.map((g) => g.type).toSet();
    final available = WellnessGoalType.values
        .where((t) => t != WellnessGoalType.custom && !owned.contains(t))
        .toList();

    final selected = await showModalBottomSheet<Set<WellnessGoalType>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _AddGoalsSheet(available: available);
      },
    );
    if (selected == null || selected.isEmpty) return;
    await ref
        .read(patientRepositoryProvider)
        .seedStarterGoals(patientId: patientId, selectedGoals: selected.toList());
    ref.read(patientDataRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupedList(
      header: 'Wellness Goals',
      children: [
        for (final goal in goals)
          GroupedListTile(
            leadingIcon: goalTypeIcon(goal.type),
            title: goal.name,
            detail: '${_f(goal.currentValue)} / ${_f(goal.targetValue)} ${goal.unit}',
            showChevron: false,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: context.colors.textTertiary,
              onPressed: () => _confirmDelete(context, ref, goal),
            ),
          ),
        GroupedListTile(
          leadingIcon: Icons.add,
          title: 'Add wellness goals',
          leadingColor: context.colors.patientAccent,
          showChevron: false,
          onTap: () => _openAddSheet(context, ref),
        ),
      ],
    );
  }
}

class _AddGoalsSheet extends StatefulWidget {
  const _AddGoalsSheet({required this.available});

  final List<WellnessGoalType> available;

  @override
  State<_AddGoalsSheet> createState() => _AddGoalsSheetState();
}

class _AddGoalsSheetState extends State<_AddGoalsSheet> {
  final Set<WellnessGoalType> _selected = {};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add wellness goals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            widget.available.isEmpty
                ? "You're already tracking every goal type."
                : 'Pick a habit to start tracking.',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          if (widget.available.isEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            for (final type in widget.available)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GoalPickerCard(
                  type: type,
                  selected: _selected.contains(type),
                  onTap: () => setState(() {
                    if (!_selected.add(type)) _selected.remove(type);
                  }),
                ),
              ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: 'Add Selected',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected),
            ),
          ],
        ],
      ),
    );
  }
}