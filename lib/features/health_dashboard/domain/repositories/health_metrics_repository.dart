import '../entities/health_metric.dart';
import '../entities/metric_type.dart';
import '../entities/vital_summary.dart';

abstract class HealthMetricsRepository {
  List<VitalSummary> getDashboardSummaries(String patientId);

  List<HealthMetric> getHistory(String patientId, MetricType type);

  Future<HealthMetric> logMetric(HealthMetric metric);
}
