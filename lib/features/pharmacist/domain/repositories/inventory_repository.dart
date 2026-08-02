import '../entities/inventory_item.dart';

abstract class InventoryRepository {
  List<InventoryItem> getInventory(String pharmacyId);

  List<InventoryItem> getLowStock(String pharmacyId);

  Future<InventoryItem> updateStock(String itemId, int newStock);

  /// Registers a brand-new medication into inventory — distinct from
  /// restocking an item that's already on file.
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
