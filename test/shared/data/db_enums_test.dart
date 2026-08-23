import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/shared/data/db_enums.dart';

void main() {
  group('userRole mapping', () {
    test('round-trips every value', () {
      for (final role in UserRole.values) {
        expect(userRoleFromDb(userRoleToDb(role)), role);
      }
    });

    test('uses the snake_case labels Postgres stores', () {
      expect(userRoleToDb(UserRole.patient), 'patient');
      expect(userRoleToDb(UserRole.doctor), 'doctor');
      expect(userRoleToDb(UserRole.pharmacist), 'pharmacist');
    });

    test('throws on an unknown label rather than guessing', () {
      expect(() => userRoleFromDb('administrator'), throwsArgumentError);
    });
  });
}
