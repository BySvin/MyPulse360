import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_patient_datasource.dart';
import '../../data/repositories/patient_repository_impl.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import '../../domain/repositories/patient_repository.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepositoryImpl(MockPatientDataSource(ref.watch(mockDatabaseProvider)));
});

/// Bumped after any mutating call (onboarding, profile update) so dependent
/// providers re-read the mock store.
final patientDataRevisionProvider = StateProvider<int>((ref) => 0);

final patientProfileProvider = Provider.family<PatientProfile?, String>((ref, patientId) {
  ref.watch(patientDataRevisionProvider);
  return ref.watch(patientRepositoryProvider).getProfile(patientId);
});

final wellnessGoalsProvider = Provider.family<List<WellnessGoal>, String>((ref, patientId) {
  ref.watch(patientDataRevisionProvider);
  return ref.watch(patientRepositoryProvider).getWellnessGoals(patientId);
});

final onboardingCompleteProvider = Provider.family<bool, String>((ref, patientId) {
  return ref.watch(patientProfileProvider(patientId)) != null;
});
