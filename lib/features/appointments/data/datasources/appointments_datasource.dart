import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';

abstract class AppointmentsDataSource {
  List<Appointment> getForPatient(String patientId);

  List<Appointment> getForDoctor(String doctorId);

  Appointment? getNextUpcoming(String patientId);

  List<TimeSlot> getAvailableSlots({required String doctorId, required DateTime date});

  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  });

  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status);

  Future<Appointment> reschedule(String appointmentId, DateTime newTime);
}
