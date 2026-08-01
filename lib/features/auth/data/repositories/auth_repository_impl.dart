import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthDataSource _dataSource;

  @override
  Future<AppUser> login({required String email, required String password}) =>
      _dataSource.login(email: email, password: password);

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) =>
      _dataSource.signUp(email: email, password: password, fullName: fullName, role: role);

  @override
  Future<void> logout() async {}

  @override
  AppUser? getUserById(String id) => _dataSource.getUserById(id);
}
