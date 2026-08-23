import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_enums.dart';
import '../../../../shared/data/db_failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import 'auth_datasource.dart';

/// Auth against Supabase. Sessions are persisted by the SDK, so nothing here
/// stores a user id — `client.auth.currentUser` is the source of truth.
class SupabaseAuthDataSource implements AuthDataSource {
  SupabaseAuthDataSource(this._client);

  final SupabaseClient _client;

  static const _profileColumns =
      'id, email, full_name, role, clinic_id, phone, avatar_url, is_active, must_change_password';

  AppUser _toUser(Map<String, dynamic> row) => AppUser(
        id: row['id'] as String,
        email: row['email'] as String,
        fullName: row['full_name'] as String,
        role: userRoleFromDb(row['role'] as String),
        clinicId: row['clinic_id'] as String,
        phone: row['phone'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        isActive: row['is_active'] as bool,
        mustChangePassword: row['must_change_password'] as bool,
      );

  Future<AppUser> _profileFor(String id) async {
    final row = await _client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const DbFailure('Your account has no profile. Contact the clinic.');
    }
    return _toUser(row);
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
    required bool isWebPlatform,
  }) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      final id = response.user?.id;
      if (id == null) {
        throw const DbFailure('That email and password do not match.');
      }

      // signInWithPassword has already established a session. Any refusal from
      // here on must tear it down, or a login the user saw fail leaves usable
      // credentials behind.
      final AppUser user;
      try {
        user = await _profileFor(id);
      } catch (_) {
        await _client.auth.signOut();
        rethrow;
      }

      // Same two refusals the mock enforces: a deactivated account cannot
      // sign in even with the right password, and staff sign in through the
      // web dashboard only. Sign out again so a refused login leaves no
      // usable session behind.
      if (!user.isActive) {
        await _client.auth.signOut();
        throw const DbFailure('That account has been deactivated.');
      }
      if (!isWebPlatform && user.role != UserRole.patient) {
        await _client.auth.signOut();
        throw const DbFailure('Staff accounts sign in on the web dashboard.');
      }

      return user;
    } on DbFailure {
      rethrow;
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    throw UnimplementedError('Sign-up lands in Task 7');
  }

  @override
  Future<AppUser> createStaffAccount({
    required String email,
    required String tempPassword,
    required String fullName,
    required UserRole role,
    required String clinicId,
  }) async {
    throw UnimplementedError('Staff creation lands in Task 8');
  }

  @override
  Future<void> setAccountActive({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _client.from('profiles').update({'is_active': isActive}).eq('id', userId);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String newPassword,
  }) async {
    throw UnimplementedError('Password change lands in Task 7');
  }

  @override
  Future<List<AppUser>> getStaffAccounts() async {
    try {
      final rows = await _client
          .from('profiles')
          .select(_profileColumns)
          .neq('role', userRoleToDb(UserRole.patient))
          .order('full_name');
      return rows.map((r) => _toUser(r)).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<AppUser?> getUserById(String id) async {
    try {
      final row = await _client
          .from('profiles')
          .select(_profileColumns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _toUser(row);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
}
