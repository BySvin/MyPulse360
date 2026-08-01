import '../../../prescriptions/domain/entities/prescription.dart';
import '../repositories/pharmacist_repository.dart';

class GetPharmacyQueueUseCase {
  GetPharmacyQueueUseCase(this._repository);

  final PharmacistRepository _repository;

  List<Prescription> call(String pharmacyId) => _repository.getQueue(pharmacyId);
}
