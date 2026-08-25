import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env/env.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_patient_datasource.dart';
import '../../data/datasources/patient_datasource.dart';
import '../../data/datasources/supabase_patient_datasource.dart';
import '../../data/repositories/patient_repository_impl.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import '../../domain/repositories/patient_repository.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final PatientDataSource dataSource = Env.isMockMode
      ? MockPatientDataSource(ref.watch(mockDatabaseProvider))
      : SupabasePatientDataSource(ref.watch(supabaseClientProvider));
  return PatientRepositoryImpl(dataSource);
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
