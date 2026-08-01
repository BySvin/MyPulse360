import 'package:equatable/equatable.dart';

class PrescriptionItem extends Equatable {
  const PrescriptionItem({
    required this.id,
    required this.medicationName,
    required this.strength,
    required this.form,
    required this.quantity,
    required this.unit,
    required this.frequency,
    required this.durationDays,
    required this.instructions,
    this.refillsAllowed = 0,
  });

  final String id;
  final String medicationName;
  final String strength;
  final String form;
  final int quantity;
  final String unit;
  final String frequency;
  final int durationDays;
  final String instructions;
  final int refillsAllowed;

  @override
  List<Object?> get props => [
        id,
        medicationName,
        strength,
        form,
        quantity,
        unit,
        frequency,
        durationDays,
        instructions,
        refillsAllowed,
      ];
}
