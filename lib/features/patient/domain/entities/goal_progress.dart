import 'package:equatable/equatable.dart';

class GoalProgress extends Equatable {
  const GoalProgress({
    required this.id,
    required this.goalId,
    required this.logDate,
    required this.value,
    this.notes,
  });

  final String id;
  final String goalId;
  final DateTime logDate;
  final double value;
  final String? notes;

  @override
  List<Object?> get props => [id, goalId, logDate, value, notes];
}
