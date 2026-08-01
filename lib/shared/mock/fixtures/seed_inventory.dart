import '../../../features/pharmacist/domain/entities/inventory_item.dart';
import '../mock_ids.dart';

List<InventoryItem> seedInventory() {
  final now = DateTime.now();
  return [
    InventoryItem(
      id: 'inv-metformin',
      pharmacyId: MockIds.fatimaPharmacistId,
      medicationName: 'Metformin',
      strength: '500mg',
      form: 'tablet',
      currentStock: 420,
      reorderLevel: 100,
      unitCost: 0.12,
      expiryDate: now.add(const Duration(days: 400)),
    ),
    InventoryItem(
      id: 'inv-atorvastatin',
      pharmacyId: MockIds.fatimaPharmacistId,
      medicationName: 'Atorvastatin',
      strength: '10mg',
      form: 'tablet',
      currentStock: 38,
      reorderLevel: 50,
      unitCost: 0.18,
      expiryDate: now.add(const Duration(days: 260)),
    ),
    InventoryItem(
      id: 'inv-lisinopril',
      pharmacyId: MockIds.fatimaPharmacistId,
      medicationName: 'Lisinopril',
      strength: '10mg',
      form: 'tablet',
      currentStock: 15,
      reorderLevel: 40,
      unitCost: 0.09,
      expiryDate: now.add(const Duration(days: 180)),
    ),
    InventoryItem(
      id: 'inv-amoxicillin',
      pharmacyId: MockIds.fatimaPharmacistId,
      medicationName: 'Amoxicillin',
      strength: '250mg',
      form: 'capsule',
      currentStock: 210,
      reorderLevel: 80,
      unitCost: 0.22,
      expiryDate: now.add(const Duration(days: 90)),
    ),
    InventoryItem(
      id: 'inv-albuterol',
      pharmacyId: MockIds.fatimaPharmacistId,
      medicationName: 'Albuterol Inhaler',
      strength: '90mcg',
      form: 'inhaler',
      currentStock: 6,
      reorderLevel: 15,
      unitCost: 12.50,
      expiryDate: now.add(const Duration(days: 500)),
    ),
  ];
}
