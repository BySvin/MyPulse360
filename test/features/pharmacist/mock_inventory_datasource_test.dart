import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/pharmacist/data/datasources/mock_inventory_datasource.dart';
import 'package:mypulse360/features/pharmacist/domain/entities/wastage_record.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

/// Exercises the real batch/FEFO/wastage logic added for the Inventory
/// Management module — the mock backend now carries genuine business rules
/// (oldest-expiry-first deduction, best-effort dispensing) worth testing
/// directly rather than through a mocked repository.
void main() {
  late MockDatabase db;
  late MockInventoryDataSource dataSource;

  setUp(() {
    db = MockDatabase();
    dataSource = MockInventoryDataSource(db);
  });

  group('addItem', () {
    test('creates the item and its first batch together', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.5,
        batchNumber: 'BATCH-1',
        initialQuantity: 100,
        expiryDate: DateTime.now().add(const Duration(days: 200)),
      );

      final batches = dataSource.getBatches(item.id);
      expect(batches, hasLength(1));
      expect(batches.first.quantity, 100);
    });

    test('skips creating a batch when initial quantity is zero', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.5,
        batchNumber: 'BATCH-1',
        initialQuantity: 0,
        expiryDate: DateTime.now().add(const Duration(days: 200)),
      );

      expect(dataSource.getBatches(item.id), isEmpty);
    });
  });

  group('deductForDispense (FEFO)', () {
    test('consumes the soonest-expiring batch first', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.0,
        batchNumber: 'FAR',
        initialQuantity: 50,
        expiryDate: DateTime.now().add(const Duration(days: 300)),
      );
      await dataSource.addBatch(
        itemId: item.id,
        batchNumber: 'SOON',
        quantity: 30,
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        unitCost: 1.0,
      );

      await dataSource.deductForDispense(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        quantity: 40,
      );

      final batches = dataSource.getBatches(item.id);
      final soon = batches.firstWhere((b) => b.batchNumber == 'SOON');
      final far = batches.firstWhere((b) => b.batchNumber == 'FAR');
      // 30 fully consumed from SOON, remaining 10 taken from FAR.
      expect(soon.quantity, 0);
      expect(far.quantity, 40);
    });

    test('skips expired batches entirely', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.0,
        batchNumber: 'EXPIRED',
        initialQuantity: 50,
        expiryDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      await dataSource.addBatch(
        itemId: item.id,
        batchNumber: 'VALID',
        quantity: 20,
        expiryDate: DateTime.now().add(const Duration(days: 100)),
        unitCost: 1.0,
      );

      await dataSource.deductForDispense(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        quantity: 10,
      );

      final batches = dataSource.getBatches(item.id);
      final expired = batches.firstWhere((b) => b.batchNumber == 'EXPIRED');
      final valid = batches.firstWhere((b) => b.batchNumber == 'VALID');
      expect(expired.quantity, 50, reason: 'expired batch must never be touched');
      expect(valid.quantity, 10);
    });

    test('is best-effort: deducts what is available without throwing on a shortfall', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.0,
        batchNumber: 'ONLY',
        initialQuantity: 5,
        expiryDate: DateTime.now().add(const Duration(days: 100)),
      );

      await dataSource.deductForDispense(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        quantity: 999,
      );

      expect(dataSource.getBatches(item.id).first.quantity, 0);
    });

    test('no-ops when the medication is not on file at that location', () async {
      await dataSource.deductForDispense(
        locationId: MockIds.defaultClinicId,
        medicationName: 'Nonexistent',
        strength: '1mg',
        quantity: 5,
      );
      // No throw is the assertion here.
    });
  });

  group('recordWastage', () {
    test('decrements the batch and logs a record', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.0,
        batchNumber: 'B1',
        initialQuantity: 20,
        expiryDate: DateTime.now().add(const Duration(days: 100)),
      );
      final batch = dataSource.getBatches(item.id).first;

      await dataSource.recordWastage(
        batchId: batch.id,
        quantity: 5,
        reason: WastageReason.damaged,
        recordedBy: 'user-fatima',
      );

      expect(dataSource.getBatches(item.id).first.quantity, 15);
      final records = dataSource.getWastageRecords(MockIds.defaultClinicId);
      expect(records, hasLength(1));
      expect(records.first.reason, WastageReason.damaged);
    });

    test('cannot waste more than the batch actually has', () async {
      final item = await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.0,
        batchNumber: 'B1',
        initialQuantity: 3,
        expiryDate: DateTime.now().add(const Duration(days: 100)),
      );
      final batch = dataSource.getBatches(item.id).first;

      await dataSource.recordWastage(
        batchId: batch.id,
        quantity: 50,
        reason: WastageReason.expired,
        recordedBy: 'user-fatima',
      );

      expect(dataSource.getBatches(item.id).first.quantity, 0);
    });
  });

  group('getItemByBarcode', () {
    test('finds an item by barcode at the right location, not elsewhere', () async {
      await dataSource.addItem(
        locationId: MockIds.defaultClinicId,
        medicationName: 'TestMed',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 20,
        unitCost: 1.0,
        barcode: '1234567890',
        batchNumber: 'B1',
        initialQuantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 100)),
      );

      expect(dataSource.getItemByBarcode(MockIds.defaultClinicId, '1234567890'), isNotNull);
      expect(dataSource.getItemByBarcode(MockIds.secondClinicId, '1234567890'), isNull);
      expect(dataSource.getItemByBarcode(MockIds.defaultClinicId, 'nope'), isNull);
    });
  });
}
