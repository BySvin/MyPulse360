import '../entities/drug_interaction.dart';
import '../repositories/prescriptions_repository.dart';

class CheckDrugInteractionsUseCase {
  CheckDrugInteractionsUseCase(this._repository);

  final PrescriptionsRepository _repository;

  List<DrugInteraction> call(List<String> medicationNames) => _repository.checkInteractions(medicationNames);
}
