import '../entities/prescription.dart';
import '../repositories/prescriptions_repository.dart';

class CreatePrescriptionUseCase {
  CreatePrescriptionUseCase(this._repository);

  final PrescriptionsRepository _repository;

  Future<Prescription> call(Prescription prescription) => _repository.create(prescription);
}
