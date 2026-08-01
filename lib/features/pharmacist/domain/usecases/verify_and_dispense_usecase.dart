import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/domain/repositories/prescriptions_repository.dart';

class VerifyAndDispenseUseCase {
  VerifyAndDispenseUseCase(this._repository);

  final PrescriptionsRepository _repository;

  Future<Prescription> call(String prescriptionId) =>
      _repository.updateStatus(prescriptionId, PrescriptionStatus.dispensed);
}
