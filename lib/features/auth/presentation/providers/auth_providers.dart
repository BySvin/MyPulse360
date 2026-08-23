import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../config/constants/hive_boxes.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/mock_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../state/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final AuthDataSource dataSource = MockAuthDataSource(ref.watch(mockDatabaseProvider));
  return AuthRepositoryImpl(dataSource);
});

/// Whether this build should be treated as the staff web dashboard. Kept
/// behind a provider (rather than referencing `kIsWeb` inline everywhere)
/// so login/role gating stays testable — tests override this instead of
/// needing to fake the platform.
final isWebPlatformProvider = Provider<bool>((ref) => kIsWeb);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthAuthenticated ? state.user : null;
});

/// One profile, by id. Widgets that show a doctor's or patient's name read
/// this instead of calling the repository, because that call is a network
/// round trip now and a `build()` cannot await.
///
/// Not auto-disposed: the same handful of ids are read across many screens,
/// and re-fetching a name on every navigation is wasted latency.
final userProfileProvider = FutureProvider.family<AppUser?, String>((ref, id) {
  return ref.watch(authRepositoryProvider).getUserById(id);
});

class AuthController extends Notifier<AuthState> {
  Box get _box => Hive.box(HiveBoxes.settings);

  @override
  AuthState build() {
    // Session restore becomes async in Task 9. Until then, start
    // unauthenticated and let the login screen drive.
    return const AuthUnauthenticated();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final user = await LoginUseCase(ref.read(authRepositoryProvider)).call(
        email: email,
        password: password,
        isWebPlatform: ref.read(isWebPlatformProvider),
      );
      await _box.put(HiveBoxes.keyCurrentUserId, user.id);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AuthLoading();
    try {
      final user = await SignUpUseCase(ref.read(authRepositoryProvider)).call(
        email: email,
        password: password,
        fullName: fullName,
      );
      await _box.put(HiveBoxes.keyCurrentUserId, user.id);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Used by the forced first-login "set a new password" screen — updates
  /// the *current* session's user so the router stops redirecting there.
  Future<void> changePassword({required String newPassword}) async {
    final current = state;
    if (current is! AuthAuthenticated) return;
    state = const AuthLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await ChangePasswordUseCase(repository).call(userId: current.user.id, newPassword: newPassword);
      state = AuthAuthenticated((await repository.getUserById(current.user.id))!);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> logout() async {
    await LogoutUseCase(ref.read(authRepositoryProvider)).call();
    await _box.delete(HiveBoxes.keyCurrentUserId);
    state = const AuthUnauthenticated();
  }
}
