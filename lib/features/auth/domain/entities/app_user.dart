import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.clinicId,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
    this.mustChangePassword = false,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String clinicId;
  final String? phone;
  final String? avatarUrl;

  /// Deactivated accounts (e.g. staff who left the clinic) are refused
  /// login even with a correct password.
  final bool isActive;

  /// Set on staff accounts created by a doctor; forces a "set your own
  /// password" step before the account can reach any dashboard.
  final bool mustChangePassword;

  AppUser copyWith({bool? isActive, bool? mustChangePassword}) => AppUser(
        id: id,
        email: email,
        fullName: fullName,
        role: role,
        clinicId: clinicId,
        phone: phone,
        avatarUrl: avatarUrl,
        isActive: isActive ?? this.isActive,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );

  @override
  List<Object?> get props =>
      [id, email, fullName, role, clinicId, phone, avatarUrl, isActive, mustChangePassword];
}
