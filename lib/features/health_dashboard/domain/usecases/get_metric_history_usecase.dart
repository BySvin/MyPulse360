import '../entities/health_metric.dart';
import '../entities/metric_type.dart';
import '../repositories/health_metrics_repository.dart';

class GetMetricHistoryUseCase {
  GetMetricHistoryUseCase(this._repository);

  final HealthMetricsRepository _repository;

  List<HealthMetric> call(String patientId, MetricType type) =>
      _repository.getHistory(patientId, type);
}
