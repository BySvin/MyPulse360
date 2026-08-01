import 'package:equatable/equatable.dart';

enum WellnessGoalType {
  exercise,
  hydration,
  sleep,
  diet,
  custom;

  String get label => switch (this) {
        WellnessGoalType.exercise => 'Daily Exercise',
        WellnessGoalType.hydration => 'Hydration',
        WellnessGoalType.sleep => 'Quality Sleep',
        WellnessGoalType.diet => 'Diet',
        WellnessGoalType.custom => 'Custom Goal',
      };
}

enum GoalStatus { onTrack, atRisk, excellent, behind }

class WellnessGoal extends Equatable {
  const WellnessGoal({
    required this.id,
    required this.patientId,
    required this.type,
    required this.name,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.status,
    required this.targetDate,
  });

  final String id;
  final String patientId;
  final WellnessGoalType type;
  final String name;
  final double targetValue;
  final double currentValue;
  final String unit;
  final GoalStatus status;
  final DateTime targetDate;

  double get progress => targetValue == 0 ? 0 : (currentValue / targetValue).clamp(0, 1);

  @override
  List<Object?> get props => [id, patientId, type, name, targetValue, currentValue, unit, status, targetDate];
}
