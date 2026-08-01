import '../../domain/entities/inventory_item.dart';

abstract class InventoryDataSource {
  List<InventoryItem> getInventory(String pharmacyId);

  List<InventoryItem> getLowStock(String pharmacyId);

  Future<InventoryItem> updateStock(String itemId, int newStock);
}
