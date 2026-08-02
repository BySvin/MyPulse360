import '../repositories/auth_repository.dart';

class ChangePasswordUseCase {
  ChangePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String userId, required String newPassword}) =>
      _repository.changePassword(userId: userId, newPassword: newPassword);
}
