import '../entities/prescription.dart';
import '../repositories/prescriptions_repository.dart';

class DispensePrescriptionUseCase {
  DispensePrescriptionUseCase(this._repository);

  final PrescriptionsRepository _repository;

  Future<Prescription> call(String prescriptionId) =>
      _repository.updateStatus(prescriptionId, PrescriptionStatus.dispensed);
}
