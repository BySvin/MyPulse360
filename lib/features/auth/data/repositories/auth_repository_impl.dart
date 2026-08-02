import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthDataSource _dataSource;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
    required bool isWebPlatform,
  }) =>
      _dataSource.login(email: email, password: password, isWebPlatform: isWebPlatform);

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _dataSource.signUp(email: email, password: password, fullName: fullName);

  @override
  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  }) =>
      _dataSource.createStaffAccount(
        email: email,
        tempPassword: tempPassword,
        fullName: fullName,
        role: role,
        clinicId: clinicId,
      );

  @override
  Future<void> setAccountActive({required String userId, required bool isActive}) =>
      _dataSource.setAccountActive(userId: userId, isActive: isActive);

  @override
  Future<void> changePassword({required String userId, required String newPassword}) =>
      _dataSource.changePassword(userId: userId, newPassword: newPassword);

  @override
  List<AppUser> getStaffAccounts() => _dataSource.getStaffAccounts();

  @override
  Future<void> logout() async {}

  @override
  AppUser? getUserById(String id) => _dataSource.getUserById(id);
}
