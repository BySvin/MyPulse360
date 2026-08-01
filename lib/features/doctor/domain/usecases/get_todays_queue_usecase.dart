import '../../../appointments/domain/entities/appointment.dart';
import '../repositories/doctor_repository.dart';

class GetTodaysQueueUseCase {
  GetTodaysQueueUseCase(this._repository);

  final DoctorRepository _repository;

  List<Appointment> call(String doctorId) => _repository.getTodaysQueue(doctorId);
}
