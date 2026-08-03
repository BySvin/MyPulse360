import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';

/// Segmented progress bar + "Step X of Y" label shared by every onboarding
/// screen (Welcome, Emergency Contact, Healthcare Preferences, Wellness
/// Goals, Health Profile Setup) so the 5-step journey reads consistently.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.step, this.totalSteps = 5});

  /// 1-based current step.
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (i) {
            final active = i < step;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: active ? colors.patientAccent : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text('Step $step of $totalSteps', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}
