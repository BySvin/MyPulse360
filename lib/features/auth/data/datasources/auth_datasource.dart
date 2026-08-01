import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

abstract class AuthDataSource {
  Future<AppUser> login({required String email, required String password});

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });

  AppUser? getUserById(String id);
}
