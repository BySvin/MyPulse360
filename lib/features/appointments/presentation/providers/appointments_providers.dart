import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_appointments_datasource.dart';
import '../../data/repositories/appointments_repository_impl.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/appointments_repository.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepositoryImpl(
    MockAppointmentsDataSource(ref.watch(mockDatabaseProvider)),
  );
});

/// Kept, not deleted.
///
/// Spec §7 calls for removing this once realtime replaces it, but scheduling
/// and pharmacist providers still watch it and are still mock-backed. Deleting
/// it now breaks their refresh. It goes in the cutover slice, when nothing
/// mock-backed is left to need it.
final appointmentsRevisionProvider = StateProvider<int>((ref) => 0);

final patientAppointmentsProvider =
    FutureProvider.family<List<Appointment>, String>((ref, patientId) {
      ref.watch(appointmentsRevisionProvider);
      return ref.watch(appointmentsRepositoryProvider).getForPatient(patientId);
    });

final doctorAppointmentsProvider =
    FutureProvider.family<List<Appointment>, String>((ref, doctorId) {
      ref.watch(appointmentsRevisionProvider);
      return ref.watch(appointmentsRepositoryProvider).getForDoctor(doctorId);
    });

final nextUpcomingAppointmentProvider =
    StreamProvider.family<Appointment?, String>((ref, patientId) {
      // Same reasoning as todaysQueueProvider: the mock's Stream.value(...)
      // only ever emits once, so this is what makes the banner refresh
      // after booking/cancelling/reschedule until realtime replaces it.
      ref.watch(appointmentsRevisionProvider);
      return ref
          .watch(appointmentsRepositoryProvider)
          .watchNextUpcoming(patientId);
    });

final availableSlotsProvider =
    FutureProvider.family<List<TimeSlot>, ({String doctorId, DateTime date})>((
      ref,
      args,
    ) {
      ref.watch(appointmentsRevisionProvider);
      return ref
          .watch(appointmentsRepositoryProvider)
          .getAvailableSlots(doctorId: args.doctorId, date: args.date);
    });

final monthAvailabilityProvider =
    FutureProvider.family<
      List<({DateTime day, int openSlots, bool isOnLeave})>,
      ({String doctorId, DateTime month})
    >((ref, args) {
      ref.watch(appointmentsRevisionProvider);
      return ref
          .watch(appointmentsRepositoryProvider)
          .getMonthAvailability(doctorId: args.doctorId, month: args.month);
    });
