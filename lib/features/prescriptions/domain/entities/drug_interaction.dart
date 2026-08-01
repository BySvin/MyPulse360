import 'package:equatable/equatable.dart';

enum InteractionSeverity { low, moderate, severe }

class DrugInteraction extends Equatable {
  const DrugInteraction({
    required this.medicationA,
    required this.medicationB,
    required this.severity,
    required this.description,
  });

  final String medicationA;
  final String medicationB;
  final InteractionSeverity severity;
  final String description;

  @override
  List<Object?> get props => [medicationA, medicationB, severity, description];
}
