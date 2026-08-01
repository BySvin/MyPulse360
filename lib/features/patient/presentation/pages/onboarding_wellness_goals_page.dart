import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/role_nav_config.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/wellness_goal.dart';
import '../providers/patient_providers.dart';
import '../widgets/goal_picker_card.dart';

/// P3 — Onboarding step 4 of 4: Wellness Goals.
class OnboardingWellnessGoalsPage extends ConsumerStatefulWidget {
  const OnboardingWellnessGoalsPage({super.key});

  @override
  ConsumerState<OnboardingWellnessGoalsPage> createState() => _OnboardingWellnessGoalsPageState();
}

class _OnboardingWellnessGoalsPageState extends ConsumerState<OnboardingWellnessGoalsPage> {
  final Set<WellnessGoalType> _selected = {WellnessGoalType.exercise, WellnessGoalType.hydration};
  bool _saving = false;

  Future<void> _finish() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    await ref.read(patientRepositoryProvider).completeOnboarding(
          patientId: user.id,
          assignedDoctorId: 'user-dr-ahmed',
          selectedGoals: _selected.toList(),
        );
    ref.read(patientDataRevisionProvider.notifier).state++;
    if (!mounted) return;
    context.go(kRoleNavConfig[UserRole.patient]!.rootPath);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(4, (i) {
                  final active = i < 4;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: active ? colors.patientAccent : colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text('Step 4 of 4', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              const SizedBox(height: 16),
              Text('Set your wellness goals', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Pick a few habits to track. You can change these anytime from your profile.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: WellnessGoalType.values.length - 1, // exclude "custom"
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final type = WellnessGoalType.values[i];
                    return GoalPickerCard(
                      type: type,
                      selected: _selected.contains(type),
                      onTap: () => setState(() {
                        if (!_selected.add(type)) _selected.remove(type);
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Finish',
                onPressed: _selected.isEmpty ? null : _finish,
                loading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
