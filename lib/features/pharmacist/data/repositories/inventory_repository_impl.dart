import '../../domain/entities/dispense_record.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/wastage_record.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_datasource.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._dataSource);

  final InventoryDataSource _dataSource;

  @override
  List<InventoryItem> getInventory(String locationId) => _dataSource.getInventory(locationId);

  @override
  List<InventoryBatch> getBatches(String itemId) => _dataSource.getBatches(itemId);

  @override
  List<InventoryBatch> getBatchesForLocation(String locationId) =>
      _dataSource.getBatchesForLocation(locationId);

  @override
  List<Supplier> getSuppliers() => _dataSource.getSuppliers();

  @override
  List<WastageRecord> getWastageRecords(String locationId) => _dataSource.getWastageRecords(locationId);

  @override
  List<DispenseRecord> getDispenseRecords(String locationId) => _dataSource.getDispenseRecords(locationId);

  @override
  InventoryItem? getItemByBarcode(String locationId, String barcode) =>
      _dataSource.getItemByBarcode(locationId, barcode);

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
  }) =>
      _dataSource.addItem(
        locationId: locationId,
        medicationName: medicationName,
        strength: strength,
        form: form,
        reorderLevel: reorderLevel,
        unitCost: unitCost,
        barcode: barcode,
        batchNumber: batchNumber,
        initialQuantity: initialQuantity,
        expiryDate: expiryDate,
        supplierId: supplierId,
      );

  @override
  Future<InventoryBatch> addBatch({
    required String itemId,
    required String batchNumber,
    required int quantity,
    required DateTime expiryDate,
    required double unitCost,
    String? supplierId,
  }) =>
      _dataSource.addBatch(
        itemId: itemId,
        batchNumber: batchNumber,
        quantity: quantity,
        expiryDate: expiryDate,
        unitCost: unitCost,
        supplierId: supplierId,
      );

  @override
  Future<WastageRecord> recordWastage({
    required String batchId,
    required int quantity,
    required WastageReason reason,
    required String recordedBy,
    String? note,
  }) =>
      _dataSource.recordWastage(
        batchId: batchId,
        quantity: quantity,
        reason: reason,
        recordedBy: recordedBy,
        note: note,
      );

  @override
  Future<Supplier> addSupplier({
    required String name,
    String? contactName,
    String? phone,
    String? email,
  }) =>
      _dataSource.addSupplier(name: name, contactName: contactName, phone: phone, email: email);

  @override
  Future<void> deductForDispense({
    required String locationId,
    required String medicationName,
    required String strength,
    required int quantity,
  }) =>
      _dataSource.deductForDispense(
        locationId: locationId,
        medicationName: medicationName,
        strength: strength,
        quantity: quantity,
      );
}
