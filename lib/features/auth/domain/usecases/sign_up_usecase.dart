import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _repository.signUp(email: email, password: password, fullName: fullName);
}
