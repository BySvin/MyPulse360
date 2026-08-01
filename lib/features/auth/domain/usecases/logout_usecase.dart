import '../repositories/auth_repository.dart';

class LogoutUseCase {
  LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
