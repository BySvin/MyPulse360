import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

abstract class AuthDataSource {
  Future<AppUser> login({
    required String email,
    required String password,
    required bool isWebPlatform,
  });

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  });

  Future<void> setAccountActive({required String userId, required bool isActive});

  Future<void> changePassword({required String userId, required String newPassword});

  Future<List<AppUser>> getStaffAccounts();

  Future<AppUser?> getUserById(String id);

  Future<void> logout();
}
