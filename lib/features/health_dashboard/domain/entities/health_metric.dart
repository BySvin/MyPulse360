import 'package:equatable/equatable.dart';

import 'metric_type.dart';

class HealthMetric extends Equatable {
  const HealthMetric({
    required this.id,
    required this.patientId,
    required this.type,
    required this.value,
    required this.measuredAt,
    this.secondaryValue, // diastolic, when type == bloodPressure (value = systolic)
    this.recordedBy,
    this.notes,
  });

  final String id;
  final String patientId;
  final MetricType type;
  final double value;
  final double? secondaryValue;
  final DateTime measuredAt;
  final String? recordedBy;
  final String? notes;

  String get displayValue => switch (type) {
        MetricType.bloodPressure => '${value.toInt()}/${secondaryValue?.toInt() ?? 0}',
        MetricType.weight || MetricType.sleepHours => value.toStringAsFixed(1),
        _ => value.toInt().toString(),
      };

  @override
  List<Object?> get props => [id, patientId, type, value, secondaryValue, measuredAt, recordedBy, notes];
}
