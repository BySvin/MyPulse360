import '../entities/dispense_record.dart';
import '../entities/inventory_batch.dart';
import '../entities/inventory_item.dart';
import '../entities/supplier.dart';
import '../entities/wastage_record.dart';

abstract class InventoryRepository {
  List<InventoryItem> getInventory(String locationId);

  List<InventoryBatch> getBatches(String itemId);

  /// All batches across every item at a location — used for expiry/value
  /// summaries without an N+1 lookup per item.
  List<InventoryBatch> getBatchesForLocation(String locationId);

  List<Supplier> getSuppliers();

  List<WastageRecord> getWastageRecords(String locationId);

  List<DispenseRecord> getDispenseRecords(String locationId);

  InventoryItem? getItemByBarcode(String locationId, String barcode);

  /// Registers a brand-new medication — distinct from [addBatch], which
  /// restocks a medication already on file. Creates the item plus its
  /// first batch together, since a medication with zero batches would have
  /// no real stock to speak of.
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

  /// Deducts `quantity` of the given medication at `locationId` from
  /// batches oldest-expiry-first (FEFO), skipping already-expired batches.
  /// Best-effort — a mismatch between the prescription and what's on file
  /// shouldn't block dispensing in this mock, so it deducts as much as it
  /// can rather than throwing.
  Future<void> deductForDispense({
    required String locationId,
    required String medicationName,
    required String strength,
    required int quantity,
  });
}
