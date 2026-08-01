import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/health_metric.dart';
import '../../domain/entities/metric_type.dart';
import '../providers/health_dashboard_providers.dart';
import '../widgets/metric_insight_card.dart';
import '../widgets/metric_stats_row.dart';

/// P5 — Health Metric detail: real trend chart, stats row, insights.
class HealthMetricDetailPage extends ConsumerWidget {
  const HealthMetricDetailPage({super.key, required this.type});

  final MetricType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    final List<HealthMetric> history = user == null
        ? const []
        : ref.watch(metricHistoryProvider((user.id, type)));

    return Scaffold(
      appBar: LargeTitleAppBar(title: type.label),
      body: history.isEmpty
          ? const EmptyStateView(
              title: 'No readings yet',
              message: 'Log a reading from the dashboard to see your trend here.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last ${history.length} days', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                horizontalInterval: _rangeStep(history),
                                getDrawingHorizontalLine: (_) => FlLine(color: colors.border, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    getTitlesWidget: (v, meta) => Text(
                                      v.toInt().toString(),
                                      style: TextStyle(fontSize: 10, color: colors.textTertiary),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (v, meta) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= history.length) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          DateFormatters.weekdayShort(history[i].measuredAt),
                                          style: TextStyle(fontSize: 10, color: colors.textTertiary),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => colors.textPrimary,
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: true,
                                  color: colors.success,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(show: true, color: colors.success.withValues(alpha: 0.1)),
                                  spots: [
                                    for (var i = 0; i < history.length; i++)
                                      FlSpot(i.toDouble(), history[i].value),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: MetricStatsRow(stats: _stats(history, type)),
                  ),
                  const SizedBox(height: 16),
                  MetricInsightCard(text: _insight(history, type)),
                ],
              ),
            ),
    );
  }

  double _rangeStep(List<HealthMetric> history) {
    final values = history.map((m) => m.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();
    return range < 1 ? 1 : range / 3;
  }

  List<MetricStat> _stats(List<HealthMetric> history, MetricType type) {
    final values = history.map((m) => m.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    String fmt(double v) => type == MetricType.weight ? v.toStringAsFixed(1) : v.toInt().toString();
    return [
      MetricStat('Average', fmt(avg)),
      MetricStat('Lowest', fmt(min)),
      MetricStat('Highest', fmt(max)),
    ];
  }

  String _insight(List<HealthMetric> history, MetricType type) {
    final values = history.map((m) => m.value).toList();
    final delta = values.last - values.first;
    return switch (type) {
      MetricType.weight => delta <= 0
          ? 'You\'re trending down ${delta.abs().toStringAsFixed(1)}kg over this period — keep it up.'
          : 'Weight has increased ${delta.toStringAsFixed(1)}kg over this period.',
      MetricType.bloodPressure => 'Readings have stayed within a normal range this period.',
      MetricType.bloodSugar => 'Your fasting readings are trending ${delta <= 0 ? 'down' : 'up'}, mostly within target.',
      MetricType.heartRate => 'Resting heart rate looks steady and within a healthy range.',
    };
  }
}
