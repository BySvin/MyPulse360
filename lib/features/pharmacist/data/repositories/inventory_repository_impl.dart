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

  @override
  Future<InventoryItem> addItem({
    required String pharmacyId,
    required String medicationName,
    required String strength,
    required String form,
    required int currentStock,
    required int reorderLevel,
    required double unitCost,
    required DateTime expiryDate,
  }) =>
      _dataSource.addItem(
        pharmacyId: pharmacyId,
        medicationName: medicationName,
        strength: strength,
        form: form,
        currentStock: currentStock,
        reorderLevel: reorderLevel,
        unitCost: unitCost,
        expiryDate: expiryDate,
      );
}
