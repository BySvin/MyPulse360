import '../entities/app_user.dart';
import '../entities/user_role.dart';

abstract class AuthRepository {
  /// Verifies email + password against the mock credential store. Rejects
  /// deactivated accounts, and (when [isWebPlatform] is false) rejects
  /// non-patient accounts — doctors and pharmacists sign in through the web
  /// dashboard only.
  Future<AppUser> login({
    required String email,
    required String password,
    required bool isWebPlatform,
  });

  /// Self-service registration. Always creates a [UserRole.patient] account
  /// — there is no way for a caller to request another role here by design.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  /// Admin-style provisioning: only a doctor's dashboard can call this, and
  /// only to create Doctor/Pharmacist accounts. The new account is flagged
  /// [AppUser.mustChangePassword] so the temp password can't be used
  /// indefinitely.
  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  });

  Future<void> setAccountActive({required String userId, required bool isActive});

  Future<void> changePassword({required String userId, required String newPassword});

  /// Replaces the temporary email set during staff provisioning with the
  /// staff member's permanent email.
  Future<AppUser> updateEmail({required String newEmail, String? userId});

  /// Doctor/pharmacist accounts only — backs the staff management screen.
  Future<List<AppUser>> getStaffAccounts();

  Future<void> logout();

  Future<AppUser?> getUserById(String id);
}
