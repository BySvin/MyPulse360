import '../../domain/entities/health_metric.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';
import '../../domain/repositories/health_metrics_repository.dart';
import '../datasources/health_metrics_datasource.dart';

class HealthMetricsRepositoryImpl implements HealthMetricsRepository {
  HealthMetricsRepositoryImpl(this._dataSource);

  final HealthMetricsDataSource _dataSource;

  @override
  List<VitalSummary> getDashboardSummaries(String patientId) =>
      _dataSource.getDashboardSummaries(patientId);

  @override
  List<HealthMetric> getHistory(String patientId, MetricType type) =>
      _dataSource.getHistory(patientId, type);

  @override
  Future<HealthMetric> logMetric(HealthMetric metric) => _dataSource.logMetric(metric);
}
