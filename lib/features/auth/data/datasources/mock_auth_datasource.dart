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

class MockAuthDataSource implements AuthDataSource {
  MockAuthDataSource(this._db);

  final MockDatabase _db;

  @override
  Future<AppUser> login({required String email, required String password}) async {
    await simulateLatency();
    final normalized = email.trim().toLowerCase();
    for (final user in _db.users) {
      if (user.email.toLowerCase() == normalized) return user;
    }
    throw AuthException('No account found for $email.');
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    await simulateLatency();
    final normalized = email.trim().toLowerCase();
    final exists = _db.users.any((u) => u.email.toLowerCase() == normalized);
    if (exists) throw AuthException('An account with this email already exists.');

    final user = AppUser(
      id: generateId(),
      email: email.trim(),
      fullName: fullName.trim(),
      role: role,
      clinicId: MockIds.defaultClinicId,
    );
    _db.users.add(user);
    return user;
  }

  @override
  AppUser? getUserById(String id) => _db.userById(id);
}
