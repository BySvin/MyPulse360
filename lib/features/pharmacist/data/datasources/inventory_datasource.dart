import '../../domain/entities/dispense_record.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/wastage_record.dart';

abstract class InventoryDataSource {
  List<InventoryItem> getInventory(String locationId);

  List<InventoryBatch> getBatches(String itemId);

  List<InventoryBatch> getBatchesForLocation(String locationId);

  List<Supplier> getSuppliers();

  List<WastageRecord> getWastageRecords(String locationId);

  List<DispenseRecord> getDispenseRecords(String locationId);

  InventoryItem? getItemByBarcode(String locationId, String barcode);

  Future<InventoryItem> addItem({
    required String locationId,
    required String medicationName,
    required String strength,
    required String form,
    required int reorderLevel,
    required double unitCost,
    String? barcode,
    required String batchNumber,
    required int initialQuantity,
    required DateTime expiryDate,
    String? supplierId,
  });

  Future<InventoryBatch> addBatch({
    required String itemId,
    required String batchNumber,
    required int quantity,
    required DateTime expiryDate,
    required double unitCost,
    String? supplierId,
  });

  Future<WastageRecord> recordWastage({
    required String batchId,
    required int quantity,
    required WastageReason reason,
    required String recordedBy,
    String? note,
  });

  Future<Supplier> addSupplier({
    required String name,
    String? contactName,
    String? phone,
    String? email,
  });

  Future<void> deductForDispense({
    required String locationId,
    required String medicationName,
    required String strength,
    required int quantity,
  });
}
