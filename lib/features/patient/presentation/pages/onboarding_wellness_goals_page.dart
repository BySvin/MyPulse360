import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/wellness_goal.dart';
import '../providers/patient_providers.dart';
import '../widgets/goal_picker_card.dart';
import '../widgets/onboarding_progress_bar.dart';

/// P3 — Onboarding step 4 of 5: Wellness Goals. The profile itself was
/// already created right after signup; this step only seeds starter goals.
/// Followed by Health Profile Setup (step 5) before landing on the
/// dashboard.
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
    await ref.read(patientRepositoryProvider).seedStarterGoals(
          patientId: user.id,
          selectedGoals: _selected.toList(),
        );
    ref.read(patientDataRevisionProvider.notifier).state++;
    if (!mounted) return;
    context.go(RoutePaths.onboardingHealthProfile);
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
              const OnboardingProgressBar(step: 4),
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
