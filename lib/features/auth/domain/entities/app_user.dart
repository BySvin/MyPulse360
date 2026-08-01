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
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String clinicId;
  final String? phone;
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, email, fullName, role, clinicId, phone, avatarUrl];
}
