import '../../../features/patient/domain/entities/wellness_goal.dart';
import '../mock_ids.dart';

List<WellnessGoal> seedWellnessGoals() {
  final now = DateTime.now();
  final endOfWeek = now.add(Duration(days: 7 - now.weekday));
  return [
    WellnessGoal(
      id: 'goal-exercise',
      patientId: MockIds.sarahPatientId,
      type: WellnessGoalType.exercise,
      name: 'Daily Exercise',
      targetValue: 5,
      currentValue: 3,
      unit: 'sessions',
      status: GoalStatus.onTrack,
      targetDate: endOfWeek,
    ),
    WellnessGoal(
      id: 'goal-hydration',
      patientId: MockIds.sarahPatientId,
      type: WellnessGoalType.hydration,
      name: 'Hydration',
      targetValue: 8,
      currentValue: 5,
      unit: 'glasses',
      status: GoalStatus.onTrack,
      targetDate: endOfWeek,
    ),
    WellnessGoal(
      id: 'goal-sleep',
      patientId: MockIds.sarahPatientId,
      type: WellnessGoalType.sleep,
      name: 'Quality Sleep',
      targetValue: 8,
      currentValue: 7.5,
      unit: 'hours avg',
      status: GoalStatus.excellent,
      targetDate: endOfWeek,
    ),
  ];
}
