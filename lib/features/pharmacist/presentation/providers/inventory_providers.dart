import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../data/datasources/mock_inventory_datasource.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/dispense_record.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/wastage_record.dart';
import '../../domain/repositories/inventory_repository.dart';

/// A batch counts as "expiring soon" inside this many days.
const kExpiringSoonDays = 30;

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(MockInventoryDataSource(ref.watch(mockDatabaseProvider)));
});

final inventoryRevisionProvider = StateProvider<int>((ref) => 0);

/// Which clinic location's inventory is currently being viewed.
final selectedLocationProvider = StateProvider<String>((ref) => MockIds.defaultClinicId);

final inventoryProvider = Provider.family<List<InventoryItem>, String>((ref, locationId) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getInventory(locationId);
});

final batchesProvider = Provider.family<List<InventoryBatch>, String>((ref, itemId) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getBatches(itemId);
});

final locationBatchesProvider = Provider.family<List<InventoryBatch>, String>((ref, locationId) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getBatchesForLocation(locationId);
});

final suppliersProvider = Provider<List<Supplier>>((ref) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getSuppliers();
});

final wastageRecordsProvider = Provider.family<List<WastageRecord>, String>((ref, locationId) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getWastageRecords(locationId);
});

final dispenseRecordsProvider = Provider.family<List<DispenseRecord>, String>((ref, locationId) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getDispenseRecords(locationId);
});

/// Computed stock for one medication, summed across its non-expired batches.
class ItemStock {
  const ItemStock({
    required this.totalQuantity,
    required this.nearestExpiry,
    required this.isLowStock,
    required this.isExpiringSoon,
  });

  final int totalQuantity;
  final DateTime? nearestExpiry;
  final bool isLowStock;
  final bool isExpiringSoon;
}

final itemStockProvider = Provider.family<ItemStock, InventoryItem>((ref, item) {
  final batches = ref.watch(batchesProvider(item.id)).where((b) => !b.isExpired && b.quantity > 0);
  var total = 0;
  DateTime? nearest;
  for (final b in batches) {
    total += b.quantity;
    if (nearest == null || b.expiryDate.isBefore(nearest)) nearest = b.expiryDate;
  }
  final expiringSoon =
      nearest != null && nearest.isBefore(DateTime.now().add(const Duration(days: kExpiringSoonDays)));
  return ItemStock(
    totalQuantity: total,
    nearestExpiry: nearest,
    isLowStock: total <= item.reorderLevel,
    isExpiringSoon: expiringSoon,
  );
});

/// Location-wide roll-up used by the Inventory page summary strip and the
/// Analytics screen.
class LocationSummary {
  const LocationSummary({
    required this.lowStockCount,
    required this.expiringSoonCount,
    required this.totalValue,
  });

  final int lowStockCount;
  final int expiringSoonCount;
  final double totalValue;
}

final locationSummaryProvider = Provider.family<LocationSummary, String>((ref, locationId) {
  final items = ref.watch(inventoryProvider(locationId));
  var lowStockCount = 0;
  var expiringSoonCount = 0;
  for (final item in items) {
    final stock = ref.watch(itemStockProvider(item));
    if (stock.isLowStock) lowStockCount++;
    if (stock.isExpiringSoon) expiringSoonCount++;
  }
  final activeBatches = ref.watch(locationBatchesProvider(locationId)).where((b) => !b.isExpired);
  var totalValue = 0.0;
  for (final b in activeBatches) {
    totalValue += b.quantity * b.unitCost;
  }
  return LocationSummary(
    lowStockCount: lowStockCount,
    expiringSoonCount: expiringSoonCount,
    totalValue: totalValue,
  );
});

final wastageCostProvider = Provider.family<double, String>((ref, locationId) {
  final records = ref.watch(wastageRecordsProvider(locationId));
  final batches = ref.watch(locationBatchesProvider(locationId));
  var cost = 0.0;
  for (final record in records) {
    InventoryBatch? batch;
    for (final b in batches) {
      if (b.id == record.batchId) {
        batch = b;
        break;
      }
    }
    if (batch != null) cost += record.quantity * batch.unitCost;
  }
  return cost;
});

/// Top medications by total dispensed quantity, most-used first.
final topDispensedProvider = Provider.family<List<MapEntry<InventoryItem, int>>, String>((ref, locationId) {
  final items = ref.watch(inventoryProvider(locationId));
  final records = ref.watch(dispenseRecordsProvider(locationId));
  final totals = <String, int>{};
  for (final record in records) {
    totals[record.itemId] = (totals[record.itemId] ?? 0) + record.quantity;
  }
  final entries = items
      .where((i) => totals.containsKey(i.id))
      .map((i) => MapEntry(i, totals[i.id]!))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(5).toList();
});
