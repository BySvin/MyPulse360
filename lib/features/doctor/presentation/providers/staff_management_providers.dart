import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Bumped after any staff-account mutation (create/deactivate/reactivate)
/// so [staffAccountsProvider] re-reads from the mock store.
final staffAccountsRevisionProvider = StateProvider<int>((ref) => 0);

/// Doctor + pharmacist accounts — backs the doctor-only Staff Management
/// screen. Never includes patients.
final staffAccountsProvider = FutureProvider<List<AppUser>>((ref) {
  ref.watch(staffAccountsRevisionProvider);
  return ref.watch(authRepositoryProvider).getStaffAccounts();
});
