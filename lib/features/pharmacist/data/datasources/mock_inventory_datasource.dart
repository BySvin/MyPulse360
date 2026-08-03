import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/dispense_record.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/wastage_record.dart';
import 'inventory_datasource.dart';

class MockInventoryDataSource implements InventoryDataSource {
  MockInventoryDataSource(this._db);

  final MockDatabase _db;

  Set<String> _itemIdsFor(String locationId) =>
      _db.inventory.where((i) => i.locationId == locationId).map((i) => i.id).toSet();

  @override
  List<InventoryItem> getInventory(String locationId) {
    final list = _db.inventory.where((i) => i.locationId == locationId).toList()
      ..sort((a, b) => a.medicationName.compareTo(b.medicationName));
    return list;
  }

  @override
  List<InventoryBatch> getBatches(String itemId) {
    final list = _db.batches.where((b) => b.itemId == itemId).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }

  @override
  List<InventoryBatch> getBatchesForLocation(String locationId) {
    final itemIds = _itemIdsFor(locationId);
    return _db.batches.where((b) => itemIds.contains(b.itemId)).toList();
  }

  @override
  List<Supplier> getSuppliers() {
    final list = List<Supplier>.from(_db.suppliers)..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  List<WastageRecord> getWastageRecords(String locationId) {
    final itemIds = _itemIdsFor(locationId);
    final list = _db.wastageRecords.where((w) => itemIds.contains(w.itemId)).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return list;
  }

  @override
  List<DispenseRecord> getDispenseRecords(String locationId) {
    final itemIds = _itemIdsFor(locationId);
    final list = _db.dispenseRecords.where((d) => itemIds.contains(d.itemId)).toList()
      ..sort((a, b) => b.dispensedAt.compareTo(a.dispensedAt));
    return list;
  }

  @override
  InventoryItem? getItemByBarcode(String locationId, String barcode) {
    for (final item in _db.inventory) {
      if (item.locationId == locationId && item.barcode == barcode) return item;
    }
    return null;
  }

  @override
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
  }) async {
    await simulateLatency();
    final item = InventoryItem(
      id: generateId(),
      locationId: locationId,
      medicationName: medicationName,
      strength: strength,
      form: form,
      reorderLevel: reorderLevel,
      unitCost: unitCost,
      barcode: barcode,
    );
    _db.inventory.add(item);
    if (initialQuantity > 0) {
      _db.batches.add(
        InventoryBatch(
          id: generateId(),
          itemId: item.id,
          batchNumber: batchNumber,
          quantity: initialQuantity,
          initialQuantity: initialQuantity,
          expiryDate: expiryDate,
          unitCost: unitCost,
          receivedDate: DateTime.now(),
          supplierId: supplierId,
        ),
      );
    }
    return item;
  }

  @override
  Future<InventoryBatch> addBatch({
    required String itemId,
    required String batchNumber,
    required int quantity,
    required DateTime expiryDate,
    required double unitCost,
    String? supplierId,
  }) async {
    await simulateLatency();
    final batch = InventoryBatch(
      id: generateId(),
      itemId: itemId,
      batchNumber: batchNumber,
      quantity: quantity,
      initialQuantity: quantity,
      expiryDate: expiryDate,
      unitCost: unitCost,
      receivedDate: DateTime.now(),
      supplierId: supplierId,
    );
    _db.batches.add(batch);
    return batch;
  }

  @override
  Future<WastageRecord> recordWastage({
    required String batchId,
    required int quantity,
    required WastageReason reason,
    required String recordedBy,
    String? note,
  }) async {
    await simulateLatency();
    final i = _db.batches.indexWhere((b) => b.id == batchId);
    if (i == -1) throw StateError('Batch not found');
    final batch = _db.batches[i];
    final deducted = quantity > batch.quantity ? batch.quantity : quantity;
    _db.batches[i] = batch.copyWith(quantity: batch.quantity - deducted);
    final record = WastageRecord(
      id: generateId(),
      batchId: batchId,
      itemId: batch.itemId,
      quantity: deducted,
      reason: reason,
      recordedAt: DateTime.now(),
      recordedBy: recordedBy,
      note: note,
    );
    _db.wastageRecords.add(record);
    return record;
  }

  @override
  Future<Supplier> addSupplier({
    required String name,
    String? contactName,
    String? phone,
    String? email,
  }) async {
    await simulateLatency();
    final supplier = Supplier(
      id: generateId(),
      name: name,
      contactName: contactName,
      phone: phone,
      email: email,
    );
    _db.suppliers.add(supplier);
    return supplier;
  }

  @override
  Future<void> deductForDispense({
    required String locationId,
    required String medicationName,
    required String strength,
    required int quantity,
  }) async {
    await simulateLatency();
    InventoryItem? match;
    for (final item in _db.inventory) {
      if (item.locationId == locationId &&
          item.medicationName.toLowerCase() == medicationName.toLowerCase() &&
          item.strength.toLowerCase() == strength.toLowerCase()) {
        match = item;
        break;
      }
    }
    if (match == null) return;

    var remaining = quantity;
    var dispensed = 0;
    final candidates = _db.batches
        .where((b) => b.itemId == match!.id && !b.isExpired && b.quantity > 0)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    for (final batch in candidates) {
      if (remaining <= 0) break;
      final i = _db.batches.indexWhere((b) => b.id == batch.id);
      final take = remaining < batch.quantity ? remaining : batch.quantity;
      _db.batches[i] = batch.copyWith(quantity: batch.quantity - take);
      remaining -= take;
      dispensed += take;
    }

    if (dispensed > 0) {
      _db.dispenseRecords.add(
        DispenseRecord(
          id: generateId(),
          itemId: match.id,
          quantity: dispensed,
          dispensedAt: DateTime.now(),
        ),
      );
    }
  }
}
