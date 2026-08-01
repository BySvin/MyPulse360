import '../entities/app_user.dart';
import '../entities/user_role.dart';

abstract class AuthRepository {
  /// Mock login: matches by email only (no real credential check).
  Future<AppUser> login({required String email, required String password});

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });

  Future<void> logout();

  AppUser? getUserById(String id);
}
