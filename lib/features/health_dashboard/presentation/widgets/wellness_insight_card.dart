import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../domain/health_insights.dart';

class WellnessInsightCard extends StatelessWidget {
  const WellnessInsightCard({super.key, required this.insight});

  final HealthInsight insight;

  Color _toneColor(AppSemanticColors colors) => switch (insight.tone) {
        StatusTone.success => colors.success,
        StatusTone.warning => colors.warning,
        StatusTone.danger => colors.danger,
        StatusTone.info => colors.info,
        StatusTone.neutral => colors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = _toneColor(colors);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(insight.icon, size: 16, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  insight.message,
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
