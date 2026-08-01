import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

class GetInventoryUseCase {
  GetInventoryUseCase(this._repository);

  final InventoryRepository _repository;

  List<InventoryItem> call(String pharmacyId) => _repository.getInventory(pharmacyId);
}
