import '../../domain/entities/health_metric.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';

abstract class HealthMetricsDataSource {
  List<VitalSummary> getDashboardSummaries(String patientId);

  List<HealthMetric> getHistory(String patientId, MetricType type);

  Future<HealthMetric> logMetric(HealthMetric metric);
}
