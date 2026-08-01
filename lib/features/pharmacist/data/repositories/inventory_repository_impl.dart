import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_datasource.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._dataSource);

  final InventoryDataSource _dataSource;

  @override
  List<InventoryItem> getInventory(String pharmacyId) => _dataSource.getInventory(pharmacyId);

  @override
  List<InventoryItem> getLowStock(String pharmacyId) => _dataSource.getLowStock(pharmacyId);

  @override
  Future<InventoryItem> updateStock(String itemId, int newStock) => _dataSource.updateStock(itemId, newStock);
}
