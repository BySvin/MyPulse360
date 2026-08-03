import '../../../features/pharmacist/domain/entities/inventory_item.dart';
import '../mock_ids.dart';

/// The medication catalog only — quantity and expiry live on
/// [InventoryBatch] rows seeded separately in `seed_batches.dart`. Split
/// across two locations so the location switcher has something real to
/// switch between.
List<InventoryItem> seedInventory() => [
      const InventoryItem(
        id: 'inv-metformin',
        locationId: MockIds.defaultClinicId,
        medicationName: 'Metformin',
        strength: '500mg',
        form: 'tablet',
        reorderLevel: 100,
        unitCost: 0.12,
        barcode: '8901030865278',
      ),
      const InventoryItem(
        id: 'inv-atorvastatin',
        locationId: MockIds.defaultClinicId,
        medicationName: 'Atorvastatin',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 50,
        unitCost: 0.18,
        barcode: '8901030865285',
      ),
      const InventoryItem(
        id: 'inv-lisinopril',
        locationId: MockIds.defaultClinicId,
        medicationName: 'Lisinopril',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 40,
        unitCost: 0.09,
        barcode: '8901030865292',
      ),
      const InventoryItem(
        id: 'inv-amoxicillin',
        locationId: MockIds.defaultClinicId,
        medicationName: 'Amoxicillin',
        strength: '250mg',
        form: 'capsule',
        reorderLevel: 80,
        unitCost: 0.22,
        barcode: '8901030865308',
      ),
      const InventoryItem(
        id: 'inv-albuterol',
        locationId: MockIds.defaultClinicId,
        medicationName: 'Albuterol Inhaler',
        strength: '90mcg',
        form: 'inhaler',
        reorderLevel: 15,
        unitCost: 12.50,
        barcode: '8901030865315',
      ),
      const InventoryItem(
        id: 'inv-ibuprofen-dt',
        locationId: MockIds.secondClinicId,
        medicationName: 'Ibuprofen',
        strength: '200mg',
        form: 'tablet',
        reorderLevel: 60,
        unitCost: 0.07,
        barcode: '8901030865322',
      ),
      const InventoryItem(
        id: 'inv-cetirizine-dt',
        locationId: MockIds.secondClinicId,
        medicationName: 'Cetirizine',
        strength: '10mg',
        form: 'tablet',
        reorderLevel: 30,
        unitCost: 0.10,
        barcode: '8901030865339',
      ),
    ];
