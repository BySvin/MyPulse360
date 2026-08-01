import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../../data/datasources/mock_pharmacist_datasource.dart';
import '../../data/repositories/pharmacist_repository_impl.dart';
import '../../domain/entities/pharmacist_profile.dart';
import '../../domain/repositories/pharmacist_repository.dart';

final pharmacistRepositoryProvider = Provider<PharmacistRepository>((ref) {
  return PharmacistRepositoryImpl(MockPharmacistDataSource(ref.watch(mockDatabaseProvider)));
});

final pharmacistProfileProvider = Provider.family<PharmacistProfile?, String>((ref, pharmacistId) {
  return ref.watch(pharmacistRepositoryProvider).getProfile(pharmacistId);
});

final pharmacyQueueProvider = Provider.family<List<Prescription>, String>((ref, pharmacyId) {
  ref.watch(prescriptionsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getQueue(pharmacyId);
});

final awaitingPrescriptionProvider = Provider<List<Consultation>>((ref) {
  ref.watch(prescriptionsRevisionProvider);
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(pharmacistRepositoryProvider).getAwaitingPrescription();
});
