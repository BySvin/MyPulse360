import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/inventory_item.dart';
import 'inventory_datasource.dart';

class MockInventoryDataSource implements InventoryDataSource {
  MockInventoryDataSource(this._db);

  final MockDatabase _db;

  @override
  List<InventoryItem> getInventory(String pharmacyId) {
    final list = _db.inventory.where((i) => i.pharmacyId == pharmacyId).toList()
      ..sort((a, b) => a.medicationName.compareTo(b.medicationName));
    return list;
  }

  @override
  List<InventoryItem> getLowStock(String pharmacyId) =>
      getInventory(pharmacyId).where((i) => i.isLowStock).toList();

  @override
  Future<InventoryItem> updateStock(String itemId, int newStock) async {
    await simulateLatency();
    final i = _db.inventory.indexWhere((item) => item.id == itemId);
    if (i == -1) throw StateError('Inventory item not found');
    final updated = _db.inventory[i].copyWith(currentStock: newStock);
    _db.inventory[i] = updated;
    return updated;
  }

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
  }) async {
    await simulateLatency();
    final item = InventoryItem(
      id: generateId(),
      pharmacyId: pharmacyId,
      medicationName: medicationName,
      strength: strength,
      form: form,
      currentStock: currentStock,
      reorderLevel: reorderLevel,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
    _db.inventory.add(item);
    return item;
  }
}
