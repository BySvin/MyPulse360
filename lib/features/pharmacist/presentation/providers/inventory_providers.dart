import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_inventory_datasource.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(MockInventoryDataSource(ref.watch(mockDatabaseProvider)));
});

final inventoryRevisionProvider = StateProvider<int>((ref) => 0);

final inventoryProvider = Provider.family<List<InventoryItem>, String>((ref, pharmacyId) {
  ref.watch(inventoryRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).getInventory(pharmacyId);
});
