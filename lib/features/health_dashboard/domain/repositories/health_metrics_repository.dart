import '../entities/health_metric.dart';
import '../entities/health_platform_connection.dart';
import '../entities/metric_type.dart';
import '../entities/vital_summary.dart';

abstract class HealthMetricsRepository {
  List<VitalSummary> getDashboardSummaries(String patientId);

  List<HealthMetric> getHistory(String patientId, MetricType type);

  Future<HealthMetric> logMetric(HealthMetric metric);

  HealthPlatformConnection? getConnection(String patientId);

  /// Connects the given platform and immediately seeds a realistic 7-day
  /// history across every device-sourced metric, the way a real HealthKit/
  /// Google Fit permission grant would backfill recent history.
  Future<HealthPlatformConnection> connectPlatform(String patientId, HealthPlatform platform);

  /// Disconnects the platform. Already-synced readings are kept — same as
  /// unlinking Apple Health in real life doesn't delete your data.
  Future<void> disconnectPlatform(String patientId);

  /// Generates one new day of plausible readings across every
  /// device-sourced metric type, as if the phone had just synced.
  Future<void> syncNow(String patientId);
}
