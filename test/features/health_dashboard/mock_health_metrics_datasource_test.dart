import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/health_dashboard/data/datasources/mock_health_metrics_datasource.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/health_metric.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/health_platform_connection.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/metric_type.dart';
import 'package:mypulse360/features/health_dashboard/domain/entities/vital_summary.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

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

  test('flags low steps and low sleep as not normal', () {
    db.healthMetrics.addAll([
      HealthMetric(
        id: 's1',
        patientId: 'test-patient',
        type: MetricType.steps,
        value: 2000,
        measuredAt: DateTime.now(),
      ),
      HealthMetric(
        id: 'sl1',
        patientId: 'test-patient',
        type: MetricType.sleepHours,
        value: 4.5,
        measuredAt: DateTime.now(),
      ),
    ]);

    final summaries = dataSource.getDashboardSummaries('test-patient');
    final steps = summaries.firstWhere((s) => s.type == MetricType.steps);
    final sleep = summaries.firstWhere((s) => s.type == MetricType.sleepHours);

    expect(steps.isNormal, isFalse);
    expect(sleep.isNormal, isFalse);
  });

  group('connectPlatform', () {
    test('backfills 7 days across every metric type', () async {
      await dataSource.connectPlatform(MockIds.sarahUserId, HealthPlatform.appleHealth);

      for (final type in MetricType.values) {
        expect(dataSource.getHistory(MockIds.sarahUserId, type), hasLength(7));
      }
    });

    test('records the connection with the chosen platform', () async {
      await dataSource.connectPlatform(MockIds.sarahUserId, HealthPlatform.googleFit);

      final connection = dataSource.getConnection(MockIds.sarahUserId);
      expect(connection, isNotNull);
      expect(connection!.platform, HealthPlatform.googleFit);
      expect(connection.lastSyncedAt, isNotNull);
    });

    test("weight readings fluctuate around the patient's actual profile weight", () async {
      await dataSource.connectPlatform(MockIds.sarahUserId, HealthPlatform.appleHealth);

      final weights = dataSource.getHistory(MockIds.sarahUserId, MetricType.weight).map((m) => m.value);
      // Sarah is seeded at 72kg — every generated reading should be a small
      // fluctuation around that, not an unrelated random number.
      expect(weights.every((w) => (w - 72).abs() <= 1), isTrue);
    });
  });

  group('syncNow', () {
    test('does not duplicate a reading for the same day', () async {
      await dataSource.connectPlatform(MockIds.sarahUserId, HealthPlatform.appleHealth);
      await dataSource.syncNow(MockIds.sarahUserId);

      // Connecting already seeded today; syncing again the same day should
      // replace, not add to, today's reading.
      expect(dataSource.getHistory(MockIds.sarahUserId, MetricType.steps), hasLength(7));
    });

    test('updates lastSyncedAt', () async {
      final connection = await dataSource.connectPlatform(MockIds.sarahUserId, HealthPlatform.appleHealth);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await dataSource.syncNow(MockIds.sarahUserId);

      final updated = dataSource.getConnection(MockIds.sarahUserId);
      expect(updated!.lastSyncedAt!.isAfter(connection.lastSyncedAt!), isTrue);
    });

    test('is a no-op when nothing is connected', () async {
      await dataSource.syncNow(MockIds.sarahUserId);
      expect(dataSource.getConnection(MockIds.sarahUserId), isNull);
      expect(dataSource.getHistory(MockIds.sarahUserId, MetricType.steps), isEmpty);
    });
  });

  group('disconnectPlatform', () {
    test('clears the connection but keeps already-synced history', () async {
      await dataSource.connectPlatform(MockIds.sarahUserId, HealthPlatform.appleHealth);
      await dataSource.disconnectPlatform(MockIds.sarahUserId);

      expect(dataSource.getConnection(MockIds.sarahUserId), isNull);
      expect(dataSource.getHistory(MockIds.sarahUserId, MetricType.steps), hasLength(7));
    });
  });
}
