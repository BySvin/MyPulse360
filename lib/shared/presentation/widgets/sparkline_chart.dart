import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Minimal trend sparkline (chrome hidden) matching the design's small
/// vital-sign card charts.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 26,
    this.filled = false,
  });

  final List<double> values;
  final Color color;
  final double height;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.2 + 0.01;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: filled,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
