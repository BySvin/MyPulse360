import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_patient_datasource.dart';
import '../../data/repositories/patient_repository_impl.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import '../../domain/repositories/patient_repository.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepositoryImpl(
    MockPatientDataSource(ref.watch(mockDatabaseProvider)),
  );
});

/// Bumped after any mutating call (onboarding, profile update) so dependent
/// providers re-read the mock store.
final patientDataRevisionProvider = StateProvider<int>((ref) => 0);

final patientProfileProvider = FutureProvider.family<PatientProfile?, String>((
  ref,
  patientId,
) {
  ref.watch(patientDataRevisionProvider);
  return ref.watch(patientRepositoryProvider).getProfile(patientId);
});

final wellnessGoalsProvider = FutureProvider.family<List<WellnessGoal>, String>(
  (ref, patientId) {
    ref.watch(patientDataRevisionProvider);
    return ref.watch(patientRepositoryProvider).getWellnessGoals(patientId);
  },
);

final onboardingCompleteProvider = Provider.family<bool, String>((
  ref,
  patientId,
) {
  // A profile that has not loaded yet is not "not onboarded" — treating it as
  // false is what pinned real patients to the welcome screen in Plan 02.
  return ref.watch(patientProfileProvider(patientId)).valueOrNull != null;
});
