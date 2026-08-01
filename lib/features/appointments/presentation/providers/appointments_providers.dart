import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_appointments_datasource.dart';
import '../../data/repositories/appointments_repository_impl.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/appointments_repository.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepositoryImpl(MockAppointmentsDataSource(ref.watch(mockDatabaseProvider)));
});

/// Bumped after booking/rescheduling/status changes so dependent providers
/// (dashboard banner, appointments list, doctor queue) refresh together.
final appointmentsRevisionProvider = StateProvider<int>((ref) => 0);

final patientAppointmentsProvider = Provider.family<List<Appointment>, String>((ref, patientId) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).getForPatient(patientId);
});

final doctorAppointmentsProvider = Provider.family<List<Appointment>, String>((ref, doctorId) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).getForDoctor(doctorId);
});

final nextUpcomingAppointmentProvider = Provider.family<Appointment?, String>((ref, patientId) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).getNextUpcoming(patientId);
});

final availableSlotsProvider =
    Provider.family<List<TimeSlot>, ({String doctorId, DateTime date})>((ref, args) {
  ref.watch(appointmentsRevisionProvider);
  return ref.watch(appointmentsRepositoryProvider).getAvailableSlots(doctorId: args.doctorId, date: args.date);
});
