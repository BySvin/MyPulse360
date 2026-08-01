import '../../../features/health_dashboard/domain/entities/health_metric.dart';
import '../../../features/health_dashboard/domain/entities/metric_type.dart';
import '../../utils/id_generator.dart';
import '../mock_ids.dart';

/// Seven days of history per vital for Sarah, matching the design's stated
/// figures (weight trending down to 72kg, BP ~120/80, sugar ~105, HR ~72).
List<HealthMetric> seedHealthMetrics() {
  final now = DateTime.now();
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  final weight = <double>[74.1, 73.6, 73.2, 73.4, 72.9, 72.5, 72.0];
  final systolic = <double>[128, 124, 122, 126, 121, 119, 120];
  final diastolic = <double>[84, 82, 80, 83, 79, 78, 80];
  final sugar = <double>[118, 112, 109, 115, 107, 104, 105];
  final heartRate = <double>[76, 74, 78, 73, 71, 74, 72];

  final metrics = <HealthMetric>[];
  for (var i = 0; i < 7; i++) {
    final day = daysAgo(6 - i);
    metrics.addAll([
      HealthMetric(
        id: generateId(),
        patientId: MockIds.sarahPatientId,
        type: MetricType.weight,
        value: weight[i],
        measuredAt: day,
        recordedBy: MockIds.sarahPatientId,
      ),
      HealthMetric(
        id: generateId(),
        patientId: MockIds.sarahPatientId,
        type: MetricType.bloodPressure,
        value: systolic[i],
        secondaryValue: diastolic[i],
        measuredAt: day,
        recordedBy: MockIds.sarahPatientId,
      ),
      HealthMetric(
        id: generateId(),
        patientId: MockIds.sarahPatientId,
        type: MetricType.bloodSugar,
        value: sugar[i],
        measuredAt: day,
        recordedBy: MockIds.sarahPatientId,
      ),
      HealthMetric(
        id: generateId(),
        patientId: MockIds.sarahPatientId,
        type: MetricType.heartRate,
        value: heartRate[i],
        measuredAt: day,
        recordedBy: MockIds.sarahPatientId,
      ),
    ]);
  }
  return metrics;
}
