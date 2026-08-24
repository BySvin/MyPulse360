import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../config/constants/hive_boxes.dart';
import '../../../../config/env/env.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/mock_auth_datasource.dart';
import '../../data/datasources/supabase_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../state/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final AuthDataSource dataSource = Env.isMockMode
      ? MockAuthDataSource(ref.watch(mockDatabaseProvider))
      : SupabaseAuthDataSource(ref.watch(supabaseClientProvider));
  return AuthRepositoryImpl(dataSource);
});

/// Whether this build should be treated as the staff web dashboard. Kept
/// behind a provider (rather than referencing `kIsWeb` inline everywhere)
/// so login/role gating stays testable — tests override this instead of
/// needing to fake the platform.
final isWebPlatformProvider = Provider<bool>((ref) => kIsWeb);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

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
    if (Env.isMockMode) {
      final storedId = _box.get(HiveBoxes.keyCurrentUserId) as String?;
      if (storedId == null) return const AuthUnauthenticated();
      // Mock lookups are in-memory, so this future completes synchronously
      // enough that the splash screen never appears.
      _restore(storedId);
      return const AuthLoading();
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthUnauthenticated();
    _restore(session.user.id);
    return const AuthLoading();
  }

  /// Fetches the profile behind an already-valid session. A failure here
  /// means the session is good but the profile is not readable, which is a
  /// real error rather than a reason to show the login screen.
  Future<void> _restore(String userId) async {
    try {
      final user = await ref.read(authRepositoryProvider).getUserById(userId);
      if (user == null) {
        state = const AuthUnauthenticated();
        return;
      }
      await _ensureLocalPatientProfile(user);
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Everything except auth still reads the in-memory mock, and that store is
  /// keyed by user id. A Supabase-backed patient carries a real UUID the mock
  /// has never seen, so `patientProfileProvider` never resolves a profile for
  /// them and the router/post-login redirect both read that as "not
  /// onboarded", pinning them to the welcome screen forever.
  ///
  /// This lives here rather than in the sign-up page because it must also run
  /// on login and on a restored session: the mock resets on relaunch, so
  /// creating the row once at registration does not survive. Plan 03 removes
  /// this entirely when the patient feature moves to Postgres.
  Future<void> _ensureLocalPatientProfile(AppUser user) async {
    if (user.role != UserRole.patient) return;
    final existing = await ref.read(patientProfileProvider(user.id).future);
    if (existing != null) return;
    await ref
        .read(patientRepositoryProvider)
        .createInitialProfile(
          patientId: user.id,
          assignedDoctorId: MockIds.drAhmedUserId,
        );
    ref.read(patientDataRevisionProvider.notifier).state++;
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final user = await LoginUseCase(ref.read(authRepositoryProvider)).call(
        email: email,
        password: password,
        isWebPlatform: ref.read(isWebPlatformProvider),
      );
      if (Env.isMockMode) {
        await _box.put(HiveBoxes.keyCurrentUserId, user.id);
      }
      await _ensureLocalPatientProfile(user);
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
      final user = await SignUpUseCase(
        ref.read(authRepositoryProvider),
      ).call(email: email, password: password, fullName: fullName);
      if (Env.isMockMode) {
        await _box.put(HiveBoxes.keyCurrentUserId, user.id);
      }
      await _ensureLocalPatientProfile(user);
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
      await ChangePasswordUseCase(
        repository,
      ).call(userId: current.user.id, newPassword: newPassword);
      state = AuthAuthenticated(
        (await repository.getUserById(current.user.id))!,
      );
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> logout() async {
    await LogoutUseCase(ref.read(authRepositoryProvider)).call();
    if (Env.isMockMode) {
      await _box.delete(HiveBoxes.keyCurrentUserId);
    }
    state = const AuthUnauthenticated();
  }
}
