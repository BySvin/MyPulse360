import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import 'auth_datasource.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Generic message for any login failure caused by identity or credential
/// mismatch — deliberately doesn't distinguish "no such account" from
/// "wrong password" so a caller can't enumerate registered emails.
const _invalidCredentialsMessage = 'Invalid email or password.';

class MockAuthDataSource implements AuthDataSource {
  MockAuthDataSource(this._db);

  final MockDatabase _db;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
    required bool isWebPlatform,
  }) async {
    await simulateLatency();
    final normalized = email.trim().toLowerCase();
    AppUser? match;
    for (final user in _db.users) {
      if (user.email.toLowerCase() == normalized) {
        match = user;
        break;
      }
    }
    if (match == null || !_db.credentials.verify(match.id, password)) {
      throw AuthException(_invalidCredentialsMessage);
    }
    if (!match.isActive) {
      throw AuthException('This account has been deactivated. Contact your clinic administrator.');
    }
    if (!isWebPlatform && match.role != UserRole.patient) {
      throw AuthException('Doctor and pharmacist accounts sign in through the MyPulse360 web dashboard.');
    }
    return match;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await simulateLatency();
    final normalized = email.trim().toLowerCase();
    final exists = _db.users.any((u) => u.email.toLowerCase() == normalized);
    if (exists) throw AuthException('An account with this email already exists.');

    final user = AppUser(
      id: generateId(),
      email: email.trim(),
      fullName: fullName.trim(),
      role: UserRole.patient,
      clinicId: MockIds.defaultClinicId,
    );
    _db.users.add(user);
    _db.credentials.setPassword(user.id, password);
    return user;
  }

  @override
  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  }) async {
    await simulateLatency();
    if (role == UserRole.patient) {
      throw AuthException('Staff accounts must be Doctor or Pharmacist.');
    }
    final normalized = email.trim().toLowerCase();
    final exists = _db.users.any((u) => u.email.toLowerCase() == normalized);
    if (exists) throw AuthException('An account with this email already exists.');

    final user = AppUser(
      id: generateId(),
      email: email.trim(),
      fullName: fullName.trim(),
      role: role,
      clinicId: clinicId,
      mustChangePassword: true,
    );
    _db.users.add(user);
    _db.credentials.setPassword(user.id, tempPassword);
    return user;
  }

  @override
  Future<void> setAccountActive({required String userId, required bool isActive}) async {
    await simulateLatency();
    final i = _db.users.indexWhere((u) => u.id == userId);
    if (i == -1) throw AuthException('Account not found.');
    _db.users[i] = _db.users[i].copyWith(isActive: isActive);
  }

  @override
  Future<void> changePassword({required String userId, required String newPassword}) async {
    await simulateLatency();
    final i = _db.users.indexWhere((u) => u.id == userId);
    if (i == -1) throw AuthException('Account not found.');
    _db.credentials.setPassword(userId, newPassword);
    _db.users[i] = _db.users[i].copyWith(mustChangePassword: false);
  }

  @override
  List<AppUser> getStaffAccounts() => _db.users.where((u) => u.role != UserRole.patient).toList();

  @override
  AppUser? getUserById(String id) => _db.userById(id);
}
