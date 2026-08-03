import 'package:equatable/equatable.dart';

/// A medication catalog entry — the "what" (name, strength, form). Stock
/// levels and expiry now live on [InventoryBatch] rows underneath it, since
/// a pharmacy typically holds several batches of the same medication with
/// different quantities and expiry dates.
class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.locationId,
    required this.medicationName,
    required this.strength,
    required this.form,
    required this.reorderLevel,
    required this.unitCost,
    this.barcode,
  });

  final String id;

  /// Which clinic/pharmacy location this medication is stocked at.
  final String locationId;
  final String medicationName;
  final String strength;
  final String form;
  final int reorderLevel;

  /// Reference/typical unit cost, used to prefill new batches — the actual
  /// cost paid lives on each [InventoryBatch] and can vary.
  final double unitCost;
  final String? barcode;

  InventoryItem copyWith({int? reorderLevel, double? unitCost, String? barcode}) {
    return InventoryItem(
      id: id,
      locationId: locationId,
      medicationName: medicationName,
      strength: strength,
      form: form,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      unitCost: unitCost ?? this.unitCost,
      barcode: barcode ?? this.barcode,
    );
  }

  @override
  List<Object?> get props =>
      [id, locationId, medicationName, strength, form, reorderLevel, unitCost, barcode];
}
