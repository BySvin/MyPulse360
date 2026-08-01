import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

/// Donut-style ring progress indicator. Kept for reuse — the canonical
/// "Clinical Clean" dashboard uses bars, not rings, for goal progress, so
/// this is used elsewhere (e.g. metric-detail "% to target").
class ProgressRingChart extends StatelessWidget {
  const ProgressRingChart({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
    this.strokeWidth = 6,
    this.label,
  });

  final double value; // 0..1
  final Color color;
  final double size;
  final double strokeWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pct = value.clamp(0, 1);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: size / 2 - strokeWidth,
              sections: [
                PieChartSectionData(
                  value: pct * 100,
                  color: color,
                  radius: strokeWidth,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (1 - pct) * 100,
                  color: colors.surfaceMuted,
                  radius: strokeWidth,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Text(
            label ?? '${(pct * 100).round()}%',
            style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
