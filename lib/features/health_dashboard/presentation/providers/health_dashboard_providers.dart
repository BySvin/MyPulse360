import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_health_metrics_datasource.dart';
import '../../data/repositories/health_metrics_repository_impl.dart';
import '../../domain/entities/health_metric.dart';
import '../../domain/entities/health_platform_connection.dart';
import '../../domain/entities/metric_type.dart';
import '../../domain/entities/vital_summary.dart';
import '../../domain/repositories/health_metrics_repository.dart';

final healthMetricsRepositoryProvider = Provider<HealthMetricsRepository>((ref) {
  return HealthMetricsRepositoryImpl(MockHealthMetricsDataSource(ref.watch(mockDatabaseProvider)));
});

/// Bumped after logging a new reading so dependent providers refresh.
final healthMetricsRevisionProvider = StateProvider<int>((ref) => 0);

final dashboardSummariesProvider = Provider.family<List<VitalSummary>, String>((ref, patientId) {
  ref.watch(healthMetricsRevisionProvider);
  return ref.watch(healthMetricsRepositoryProvider).getDashboardSummaries(patientId);
});

final metricHistoryProvider =
    Provider.family<List<HealthMetric>, (String patientId, MetricType type)>((ref, args) {
  ref.watch(healthMetricsRevisionProvider);
  return ref.watch(healthMetricsRepositoryProvider).getHistory(args.$1, args.$2);
});

final healthPlatformConnectionProvider = Provider.family<HealthPlatformConnection?, String>((ref, patientId) {
  ref.watch(healthMetricsRevisionProvider);
  return ref.watch(healthMetricsRepositoryProvider).getConnection(patientId);
});
