import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';

/// Exercises the real credential/role logic — [MockAuthDataSource] is where
/// login actually verifies a password and enforces the mobile/web + role
/// split, not just a pass-through, so it's worth testing directly rather
/// than through a mocked repository.
void main() {
  late MockDatabase db;
  late MockAuthDataSource dataSource;

  setUp(() {
    db = MockDatabase();
    dataSource = MockAuthDataSource(db);
  });

  group('signUp', () {
    test('always creates a patient account, regardless of caller', () async {
      final user = await dataSource.signUp(
        email: 'new.patient@example.com',
        password: 'Passw0rd1!',
        fullName: 'New Patient',
      );

      expect(user.role, UserRole.patient);
    });

    test('rejects a duplicate email', () async {
      await dataSource.signUp(email: 'dup@example.com', password: 'Passw0rd1!', fullName: 'A');

      expect(
        () => dataSource.signUp(email: 'dup@example.com', password: 'Passw0rd1!', fullName: 'B'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('login', () {
    test('succeeds with the correct password', () async {
      await dataSource.signUp(email: 'sam@example.com', password: 'Passw0rd1!', fullName: 'Sam');

      final user = await dataSource.login(
        email: 'sam@example.com',
        password: 'Passw0rd1!',
        isWebPlatform: false,
      );

      expect(user.email, 'sam@example.com');
    });

    test('rejects the wrong password with a generic message', () async {
      await dataSource.signUp(email: 'sam@example.com', password: 'Passw0rd1!', fullName: 'Sam');

      expect(
        () => dataSource.login(email: 'sam@example.com', password: 'WrongPass1', isWebPlatform: false),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Invalid email or password.')),
      );
    });

    test('rejects an unknown email with the same generic message', () async {
      expect(
        () => dataSource.login(email: 'ghost@example.com', password: 'whatever', isWebPlatform: false),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', 'Invalid email or password.')),
      );
    });

    test('rejects a deactivated account', () async {
      final user = await dataSource.signUp(email: 'sam@example.com', password: 'Passw0rd1!', fullName: 'Sam');
      await dataSource.setAccountActive(userId: user.id, isActive: false);

      expect(
        () => dataSource.login(email: 'sam@example.com', password: 'Passw0rd1!', isWebPlatform: false),
        throwsA(isA<AuthException>()),
      );
    });

    test('rejects a doctor account on native mobile (isWebPlatform: false)', () async {
      final doctor = await dataSource.createStaffAccount(
        email: 'new.doctor@mypulse360.clinic',
        tempPassword: 'Passw0rd1!',
        fullName: 'New Doctor',
        role: UserRole.doctor,
        clinicId: 'clinic-001',
      );

      expect(
        () => dataSource.login(email: doctor.email, password: 'Passw0rd1!', isWebPlatform: false),
        throwsA(isA<AuthException>()),
      );

      final user = await dataSource.login(email: doctor.email, password: 'Passw0rd1!', isWebPlatform: true);
      expect(user.role, UserRole.doctor);
    });

    test('rejects a patient account on the web dashboard (isWebPlatform: true)', () async {
      await dataSource.signUp(
        email: 'web.patient@example.com',
        password: 'Passw0rd1!',
        fullName: 'Web Patient',
      );

      // The mirror of the doctor rule. Patients belong in the mobile app; the
      // web dashboard is laid out for staff and was never designed for them.
      expect(
        () => dataSource.login(
          email: 'web.patient@example.com',
          password: 'Passw0rd1!',
          isWebPlatform: true,
        ),
        throwsA(isA<AuthException>()),
      );

      final user = await dataSource.login(
        email: 'web.patient@example.com',
        password: 'Passw0rd1!',
        isWebPlatform: false,
      );
      expect(user.role, UserRole.patient);
    });
  });

  group('createStaffAccount', () {
    test('rejects UserRole.patient', () {
      expect(
        () => dataSource.createStaffAccount(
          email: 'nope@mypulse360.clinic',
          tempPassword: 'Passw0rd1!',
          fullName: 'Nope',
          role: UserRole.patient,
          clinicId: 'clinic-001',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('flags the new account as needing a password change', () async {
      final pharmacist = await dataSource.createStaffAccount(
        email: 'new.pharmacist@mypulse360.clinic',
        tempPassword: 'Passw0rd1!',
        fullName: 'New Pharmacist',
        role: UserRole.pharmacist,
        clinicId: 'clinic-001',
      );

      expect(pharmacist.mustChangePassword, isTrue);
    });
  });

  group('changePassword', () {
    test('clears mustChangePassword and rotates the credential', () async {
      final pharmacist = await dataSource.createStaffAccount(
        email: 'new.pharmacist@mypulse360.clinic',
        tempPassword: 'Passw0rd1!',
        fullName: 'New Pharmacist',
        role: UserRole.pharmacist,
        clinicId: 'clinic-001',
      );

      await dataSource.changePassword(userId: pharmacist.id, newPassword: 'BrandNew1!');

      expect((await dataSource.getUserById(pharmacist.id))!.mustChangePassword, isFalse);

      expect(
        () => dataSource.login(email: pharmacist.email, password: 'Passw0rd1!', isWebPlatform: true),
        throwsA(isA<AuthException>()),
      );
      final user = await dataSource.login(
        email: pharmacist.email,
        password: 'BrandNew1!',
        isWebPlatform: true,
      );
      expect(user.id, pharmacist.id);
    });
  });

  group('setAccountActive', () {
    test('can deactivate and reactivate an account', () async {
      final pharmacist = await dataSource.createStaffAccount(
        email: 'new.pharmacist@mypulse360.clinic',
        tempPassword: 'Passw0rd1!',
        fullName: 'New Pharmacist',
        role: UserRole.pharmacist,
        clinicId: 'clinic-001',
      );

      await dataSource.setAccountActive(userId: pharmacist.id, isActive: false);
      expect((await dataSource.getUserById(pharmacist.id))!.isActive, isFalse);

      await dataSource.setAccountActive(userId: pharmacist.id, isActive: true);
      expect((await dataSource.getUserById(pharmacist.id))!.isActive, isTrue);
    });
  });
}
