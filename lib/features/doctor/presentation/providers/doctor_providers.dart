import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../data/datasources/mock_doctor_datasource.dart';
import '../../data/repositories/doctor_repository_impl.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/entities/doctor_profile.dart';
import '../../domain/repositories/doctor_repository.dart';

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  return DoctorRepositoryImpl(
    MockDoctorDataSource(ref.watch(mockDatabaseProvider)),
  );
});

final doctorProfileProvider = Provider.family<DoctorProfile?, String>((
  ref,
  doctorId,
) {
  return ref.watch(doctorRepositoryProvider).getProfile(doctorId);
});

final todaysQueueProvider = StreamProvider.family<List<Appointment>, String>((
  ref,
  doctorId,
) {
  return ref.watch(appointmentsRepositoryProvider).watchTodaysQueue(doctorId);
});

final patientHistoryProvider = Provider.family<List<Consultation>, String>((
  ref,
  patientId,
) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(doctorRepositoryProvider).getPatientHistory(patientId);
});
