import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/health_metric.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';
import 'health_metrics_datasource.dart';

class MockHealthMetricsDataSource implements HealthMetricsDataSource {
  MockHealthMetricsDataSource(this._db);

  final MockDatabase _db;

  @override
  List<HealthMetric> getHistory(String patientId, MetricType type) {
    final list = _db.healthMetrics
        .where((m) => m.patientId == patientId && m.type == type)
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return list;
  }

  @override
  List<VitalSummary> getDashboardSummaries(String patientId) {
    return MetricType.values.map((type) {
      final history = getHistory(patientId, type);
      if (history.isEmpty) {
        return VitalSummary(
          type: type,
          latestDisplayValue: '—',
          sparkline: const [],
          trend: TrendDirection.flat,
          trendLabel: 'No data yet',
          isNormal: true,
          lastUpdated: DateTime.now(),
        );
      }
      final latest = history.last;
      final sparkline = history.map((m) => m.value).toList();
      final delta = history.length > 1 ? latest.value - history.first.value : 0.0;
      final trend = delta.abs() < 0.05
          ? TrendDirection.flat
          : (delta < 0 ? TrendDirection.down : TrendDirection.up);

      final (isNormal, statusLabel) = _statusFor(type, latest);
      final trendLabel = type == MetricType.weight
          ? '${delta <= 0 ? '↓' : '↑'} ${delta.abs().toStringAsFixed(1)} kg this week'
          : '$statusLabel · ${DateFormatters.relative(latest.measuredAt)}';

      return VitalSummary(
        type: type,
        latestDisplayValue: latest.displayValue,
        sparkline: sparkline,
        trend: trend,
        trendLabel: trendLabel,
        isNormal: isNormal,
        lastUpdated: latest.measuredAt,
      );
    }).toList();
  }

  (bool, String) _statusFor(MetricType type, HealthMetric m) {
    return switch (type) {
      MetricType.weight => (true, 'Tracked'),
      MetricType.bloodPressure =>
        (m.value <= 130 && (m.secondaryValue ?? 0) <= 85) ? (true, 'Normal') : (false, 'Elevated'),
      MetricType.bloodSugar => m.value <= 125 ? (true, 'Good') : (false, 'High'),
      MetricType.heartRate => (m.value >= 60 && m.value <= 100) ? (true, 'Normal') : (false, 'Elevated'),
    };
  }

  @override
  Future<HealthMetric> logMetric(HealthMetric metric) async {
    await simulateLatency();
    _db.healthMetrics.add(metric);
    return metric;
  }
}
