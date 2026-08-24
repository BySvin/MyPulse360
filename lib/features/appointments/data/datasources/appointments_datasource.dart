import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';

abstract class AppointmentsDataSource {
  Future<List<Appointment>> getForPatient(String patientId);

  Future<List<Appointment>> getForDoctor(String doctorId);

  /// Live: the dashboard banner re-renders when this patient books, cancels or
  /// is bumped by an approved leave.
  Stream<Appointment?> watchNextUpcoming(String patientId);

  /// Live: the doctor's queue re-orders as patients book and are seen.
  Stream<List<Appointment>> watchTodaysQueue(String doctorId);

  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  });

  /// One call per calendar month. Per-day slot queries cost 31 round trips.
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>>
  getMonthAvailability({required String doctorId, required DateTime month});

  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  });

  Future<Appointment> updateStatus(
    String appointmentId,
    AppointmentStatus status,
  );

  Future<Appointment> reschedule(String appointmentId, DateTime newTime);
}
