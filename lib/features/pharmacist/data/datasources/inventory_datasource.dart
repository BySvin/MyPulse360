import '../../domain/entities/inventory_item.dart';

abstract class InventoryDataSource {
  List<InventoryItem> getInventory(String pharmacyId);

  List<InventoryItem> getLowStock(String pharmacyId);

  Future<InventoryItem> updateStock(String itemId, int newStock);

  Future<InventoryItem> addItem({
    required String pharmacyId,
    required String medicationName,
    required String strength,
    required String form,
    required int currentStock,
    required int reorderLevel,
    required double unitCost,
    required DateTime expiryDate,
  });
}
