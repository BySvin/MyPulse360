import '../entities/consultation.dart';
import '../repositories/doctor_repository.dart';

class SubmitConsultationUseCase {
  SubmitConsultationUseCase(this._repository);

  final DoctorRepository _repository;

  Future<Consultation> call(Consultation consultation) => _repository.submitConsultation(consultation);
}
