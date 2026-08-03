import 'package:equatable/equatable.dart';

/// One received lot of a medication — the actual stock and expiry live
/// here, not on [InventoryItem], since the same medication can have
/// multiple batches on the shelf with different quantities/expiry/supplier.
class InventoryBatch extends Equatable {
  const InventoryBatch({
    required this.id,
    required this.itemId,
    required this.batchNumber,
    required this.quantity,
    required this.initialQuantity,
    required this.expiryDate,
    required this.unitCost,
    required this.receivedDate,
    this.supplierId,
  });

  final String id;
  final String itemId;
  final String batchNumber;

  /// Remaining quantity — decremented by dispensing and wastage.
  final int quantity;
  final int initialQuantity;
  final DateTime expiryDate;
  final double unitCost;
  final DateTime receivedDate;
  final String? supplierId;

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  bool isExpiringWithin(int days) =>
      !isExpired && expiryDate.isBefore(DateTime.now().add(Duration(days: days)));

  InventoryBatch copyWith({int? quantity}) {
    return InventoryBatch(
      id: id,
      itemId: itemId,
      batchNumber: batchNumber,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity,
      expiryDate: expiryDate,
      unitCost: unitCost,
      receivedDate: receivedDate,
      supplierId: supplierId,
    );
  }

  @override
  List<Object?> get props =>
      [id, itemId, batchNumber, quantity, initialQuantity, expiryDate, unitCost, receivedDate, supplierId];
}
