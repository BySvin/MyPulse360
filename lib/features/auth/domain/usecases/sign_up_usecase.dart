import '../entities/app_user.dart';
import '../entities/user_role.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) =>
      _repository.signUp(email: email, password: password, fullName: fullName, role: role);
}
