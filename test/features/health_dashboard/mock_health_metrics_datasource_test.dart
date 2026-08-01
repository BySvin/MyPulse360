import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/health_dashboard/data/datasources/mock_health_metrics_datasource.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/health_metric.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/metric_type.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/vital_summary.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';

void main() {
  late MockDatabase db;
  late MockHealthMetricsDataSource dataSource;

  setUp(() {
    db = MockDatabase();
    dataSource = MockHealthMetricsDataSource(db);
    db.healthMetrics.removeWhere((m) => m.patientId == 'test-patient');
  });

  test('flags an elevated blood-pressure reading as not normal', () {
    db.healthMetrics.add(
      HealthMetric(
        id: 'm1',
        patientId: 'test-patient',
        type: MetricType.bloodPressure,
        value: 150,
        secondaryValue: 95,
        measuredAt: DateTime.now(),
      ),
    );

    final summaries = dataSource.getDashboardSummaries('test-patient');
    final bp = summaries.firstWhere((s) => s.type == MetricType.bloodPressure);

    expect(bp.isNormal, isFalse);
    expect(bp.trendLabel, contains('Elevated'));
  });

  test('a downward weight trend is reported as trending down', () {
    final now = DateTime.now();
    db.healthMetrics.addAll([
      HealthMetric(
        id: 'w1',
        patientId: 'test-patient',
        type: MetricType.weight,
        value: 80,
        measuredAt: now.subtract(const Duration(days: 6)),
      ),
      HealthMetric(
        id: 'w2',
        patientId: 'test-patient',
        type: MetricType.weight,
        value: 78,
        measuredAt: now,
      ),
    ]);

    final summaries = dataSource.getDashboardSummaries('test-patient');
    final weight = summaries.firstWhere((s) => s.type == MetricType.weight);

    expect(weight.trend, TrendDirection.down);
    expect(weight.trendLabel, contains('2.0 kg'));
  });

  test('a metric type with no readings reports "No data yet"', () {
    final summaries = dataSource.getDashboardSummaries('patient-with-no-history');
    final heartRate = summaries.firstWhere((s) => s.type == MetricType.heartRate);

    expect(heartRate.trendLabel, 'No data yet');
    expect(heartRate.sparkline, isEmpty);
  });
}
