import '../../features/auth/domain/entities/user_role.dart';

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
