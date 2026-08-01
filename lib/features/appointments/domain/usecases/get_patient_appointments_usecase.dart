import '../entities/appointment.dart';
import '../repositories/appointments_repository.dart';

class GetPatientAppointmentsUseCase {
  GetPatientAppointmentsUseCase(this._repository);

  final AppointmentsRepository _repository;

  List<Appointment> call(String patientId) => _repository.getForPatient(patientId);
}
