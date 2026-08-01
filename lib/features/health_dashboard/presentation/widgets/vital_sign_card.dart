import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/sparkline_chart.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';

/// One cell of the dashboard's 2x2 vital-sign grid.
class VitalSignCard extends StatelessWidget {
  const VitalSignCard({super.key, required this.summary, this.onTap});

  final VitalSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = summary.type;
    final dotColor = summary.isNormal ? colors.success : colors.warning;
    final sparkColor = type == MetricType.heartRate ? const Color(0xFF3B82F6) : colors.success;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadii.sm + 2),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, size: 13, color: colors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  type.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: colors.textPrimary,
                ),
                children: [
                  TextSpan(text: summary.latestDisplayValue),
                  if (summary.type != MetricType.bloodPressure)
                    TextSpan(
                      text: ' ${type.unit}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            if (summary.sparkline.length > 1) ...[
              const SizedBox(height: 2),
              SparklineChart(values: summary.sparkline, color: sparkColor, height: 26),
            ] else
              const SizedBox(height: 26),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    summary.trendLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: summary.isNormal ? colors.successText : colors.warningText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
