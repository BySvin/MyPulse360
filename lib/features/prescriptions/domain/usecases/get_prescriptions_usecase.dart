import '../entities/prescription.dart';
import '../repositories/prescriptions_repository.dart';

class GetPrescriptionsUseCase {
  GetPrescriptionsUseCase(this._repository);

  final PrescriptionsRepository _repository;

  List<Prescription> call(String patientId) => _repository.getForPatient(patientId);
}
