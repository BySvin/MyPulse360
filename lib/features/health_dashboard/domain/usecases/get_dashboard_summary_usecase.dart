import '../entities/vital_summary.dart';
import '../repositories/health_metrics_repository.dart';

class GetDashboardSummaryUseCase {
  GetDashboardSummaryUseCase(this._repository);

  final HealthMetricsRepository _repository;

  List<VitalSummary> call(String patientId) => _repository.getDashboardSummaries(patientId);
}
