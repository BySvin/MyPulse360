import '../entities/inventory_item.dart';

abstract class InventoryRepository {
  List<InventoryItem> getInventory(String pharmacyId);

  List<InventoryItem> getLowStock(String pharmacyId);

  Future<InventoryItem> updateStock(String itemId, int newStock);
}
