import '../entities/appointment.dart';
import '../repositories/appointments_repository.dart';

class BookAppointmentUseCase {
  BookAppointmentUseCase(this._repository);

  final AppointmentsRepository _repository;

  Future<Appointment> call({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) =>
      _repository.book(
        patientId: patientId,
        doctorId: doctorId,
        scheduledAt: scheduledAt,
        appointmentType: appointmentType,
        reasonForVisit: reasonForVisit,
      );
}
