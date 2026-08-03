import 'dart:math';

import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/health_metric.dart';
import '../../domain/entities/health_platform_connection.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';
import 'health_metrics_datasource.dart';

/// Metric types a connected health platform would actually supply —
/// everything except manually-logged-only readings (there are none today;
/// all eight types are plausibly device-sourced).
const _deviceSyncedMetrics = MetricType.values;

class MockHealthMetricsDataSource implements HealthMetricsDataSource {
  MockHealthMetricsDataSource(this._db);

  final MockDatabase _db;
  final Random _random = Random();

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  double _baselineWeightKg(String patientId) {
    for (final p in _db.patients) {
      if (p.id == patientId) return p.weightKg;
    }
    return 70;
  }

  HealthMetric _generateReading(String patientId, MetricType type, DateTime day) {
    switch (type) {
      case MetricType.steps:
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: (4000 + _random.nextInt(8000)).toDouble(),
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.sleepHours:
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: 5.5 + _random.nextDouble() * 3,
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.caloriesBurned:
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: (1800 + _random.nextInt(800)).toDouble(),
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.exerciseMinutes:
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: _random.nextInt(61).toDouble(),
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.heartRate:
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: (58 + _random.nextInt(30)).toDouble(),
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.weight:
        final baseline = _baselineWeightKg(patientId);
        final delta = (_random.nextDouble() - 0.5) * 0.6;
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: baseline + delta,
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.bloodPressure:
        final systolic = 108 + _random.nextInt(18);
        final diastolic = 68 + _random.nextInt(16);
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: systolic.toDouble(),
          secondaryValue: diastolic.toDouble(),
          measuredAt: day,
          recordedBy: 'device-sync',
        );
      case MetricType.bloodSugar:
        return HealthMetric(
          id: generateId(),
          patientId: patientId,
          type: type,
          value: (85 + _random.nextInt(30)).toDouble(),
          measuredAt: day,
          recordedBy: 'device-sync',
        );
    }
  }

  /// Adds (or replaces, if one already exists for that day) one reading
  /// per device-synced metric type for [day].
  void _upsertDay(String patientId, DateTime day) {
    for (final type in _deviceSyncedMetrics) {
      _db.healthMetrics.removeWhere(
        (m) => m.patientId == patientId && m.type == type && _isSameDay(m.measuredAt, day),
      );
      _db.healthMetrics.add(_generateReading(patientId, type, day));
    }
  }

  @override
  List<HealthMetric> getHistory(String patientId, MetricType type) {
    final list = _db.healthMetrics.where((m) => m.patientId == patientId && m.type == type).toList()
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
      MetricType.steps => m.value >= 5000 ? (true, 'Active') : (false, 'Low'),
      MetricType.sleepHours => m.value >= 6.5 ? (true, 'Rested') : (false, 'Low'),
      MetricType.caloriesBurned => (true, 'Tracked'),
      MetricType.exerciseMinutes => m.value >= 20 ? (true, 'Active') : (false, 'Low'),
    };
  }

  @override
  Future<HealthMetric> logMetric(HealthMetric metric) async {
    await simulateLatency();
    _db.healthMetrics.add(metric);
    return metric;
  }

  @override
  HealthPlatformConnection? getConnection(String patientId) {
    for (final c in _db.healthPlatformConnections) {
      if (c.patientId == patientId) return c;
    }
    return null;
  }

  @override
  Future<HealthPlatformConnection> connectPlatform(String patientId, HealthPlatform platform) async {
    await simulateLatency();
    _db.healthPlatformConnections.removeWhere((c) => c.patientId == patientId);
    final now = DateTime.now();
    final connection = HealthPlatformConnection(
      patientId: patientId,
      platform: platform,
      connectedAt: now,
      lastSyncedAt: now,
    );
    _db.healthPlatformConnections.add(connection);

    final today = DateTime(now.year, now.month, now.day);
    for (var i = 6; i >= 0; i--) {
      _upsertDay(patientId, today.subtract(Duration(days: i)));
    }
    return connection;
  }

  @override
  Future<void> disconnectPlatform(String patientId) async {
    await simulateLatency();
    _db.healthPlatformConnections.removeWhere((c) => c.patientId == patientId);
  }

  @override
  Future<void> syncNow(String patientId) async {
    await simulateLatency();
    final i = _db.healthPlatformConnections.indexWhere((c) => c.patientId == patientId);
    if (i == -1) return;
    final now = DateTime.now();
    _upsertDay(patientId, DateTime(now.year, now.month, now.day));
    _db.healthPlatformConnections[i] = _db.healthPlatformConnections[i].copyWith(lastSyncedAt: now);
  }
}
