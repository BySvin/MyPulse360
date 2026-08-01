import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_prescriptions_datasource.dart';
import '../../data/repositories/prescriptions_repository_impl.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/repositories/prescriptions_repository.dart';

final prescriptionsRepositoryProvider = Provider<PrescriptionsRepository>((ref) {
  return PrescriptionsRepositoryImpl(MockPrescriptionsDataSource(ref.watch(mockDatabaseProvider)));
});

/// Bumped after create/dispense/status changes so dependent providers
/// (patient list, pharmacist queue) refresh together.
final prescriptionsRevisionProvider = StateProvider<int>((ref) => 0);

final patientPrescriptionsProvider = Provider.family<List<Prescription>, String>((ref, patientId) {
  ref.watch(prescriptionsRevisionProvider);
  return ref.watch(prescriptionsRepositoryProvider).getForPatient(patientId);
});

final pendingVerificationProvider = Provider.family<List<Prescription>, String>((ref, pharmacyId) {
  ref.watch(prescriptionsRevisionProvider);
  return ref.watch(prescriptionsRepositoryProvider).getPendingVerification(pharmacyId);
});
