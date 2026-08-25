import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/patient/domain/entities/wellness_goal.dart';

/// Postgres stores enum labels in snake_case; Dart spells them lowerCamelCase.
/// Every translation lives here so a datasource never contains a bare string,
/// and so adding an enum value fails in one place rather than silently
/// mis-mapping at the edges.

const _userRoleToDb = <UserRole, String>{
  UserRole.patient: 'patient',
  UserRole.doctor: 'doctor',
  UserRole.pharmacist: 'pharmacist',
};

String userRoleToDb(UserRole role) => _userRoleToDb[role]!;

UserRole userRoleFromDb(String label) {
  for (final entry in _userRoleToDb.entries) {
    if (entry.value == label) return entry.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown user_role from the database');
}

const _appointmentStatusToDb = <AppointmentStatus, String>{
  AppointmentStatus.scheduled: 'scheduled',
  AppointmentStatus.confirmed: 'confirmed',
  AppointmentStatus.inProgress: 'in_progress',
  AppointmentStatus.completed: 'completed',
  AppointmentStatus.cancelled: 'cancelled',
  AppointmentStatus.rescheduled: 'rescheduled',
};

String appointmentStatusToDb(AppointmentStatus s) => _appointmentStatusToDb[s]!;

AppointmentStatus appointmentStatusFromDb(String label) {
  for (final e in _appointmentStatusToDb.entries) {
    if (e.value == label) return e.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown appointment_status from the database');
}

const _wellnessGoalTypeToDb = <WellnessGoalType, String>{
  WellnessGoalType.exercise: 'exercise',
  WellnessGoalType.hydration: 'hydration',
  WellnessGoalType.sleep: 'sleep',
  WellnessGoalType.diet: 'diet',
  WellnessGoalType.custom: 'custom',
};

String wellnessGoalTypeToDb(WellnessGoalType t) => _wellnessGoalTypeToDb[t]!;

WellnessGoalType wellnessGoalTypeFromDb(String label) {
  for (final e in _wellnessGoalTypeToDb.entries) {
    if (e.value == label) return e.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown wellness_goal_type from the database');
}

const _goalStatusToDb = <GoalStatus, String>{
  GoalStatus.onTrack: 'on_track',
  GoalStatus.atRisk: 'at_risk',
  GoalStatus.excellent: 'excellent',
  GoalStatus.behind: 'behind',
};

String goalStatusToDb(GoalStatus s) => _goalStatusToDb[s]!;

GoalStatus goalStatusFromDb(String label) {
  for (final e in _goalStatusToDb.entries) {
    if (e.value == label) return e.key;
  }
  throw ArgumentError.value(label, 'label', 'Unknown goal_status from the database');
}
