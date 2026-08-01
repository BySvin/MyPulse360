import 'package:equatable/equatable.dart';

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.pharmacyId,
    required this.medicationName,
    required this.strength,
    required this.form,
    required this.currentStock,
    required this.reorderLevel,
    required this.unitCost,
    required this.expiryDate,
  });

  final String id;
  final String pharmacyId;
  final String medicationName;
  final String strength;
  final String form;
  final int currentStock;
  final int reorderLevel;
  final double unitCost;
  final DateTime expiryDate;

  bool get isLowStock => currentStock <= reorderLevel;

  InventoryItem copyWith({int? currentStock}) {
    return InventoryItem(
      id: id,
      pharmacyId: pharmacyId,
      medicationName: medicationName,
      strength: strength,
      form: form,
      currentStock: currentStock ?? this.currentStock,
      reorderLevel: reorderLevel,
      unitCost: unitCost,
      expiryDate: expiryDate,
    );
  }

  @override
  List<Object?> get props =>
      [id, pharmacyId, medicationName, strength, form, currentStock, reorderLevel, unitCost, expiryDate];
}
