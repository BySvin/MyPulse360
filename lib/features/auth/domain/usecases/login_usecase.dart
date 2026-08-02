import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String email,
    required String password,
    required bool isWebPlatform,
  }) =>
      _repository.login(email: email, password: password, isWebPlatform: isWebPlatform);
}
