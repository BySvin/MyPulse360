import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';

class MetricInsightCard extends StatelessWidget {
  const MetricInsightCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: colors.infoText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: colors.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
