import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mypulse360/features/prescriptions/domain/entities/drug_interaction.dart';
import 'package:mypulse360/features/prescriptions/domain/repositories/prescriptions_repository.dart';
import 'package:mypulse360/features/prescriptions/domain/usecases/check_drug_interactions_usecase.dart';

class MockPrescriptionsRepository extends Mock implements PrescriptionsRepository {}

void main() {
  late MockPrescriptionsRepository repository;
  late CheckDrugInteractionsUseCase useCase;

  setUp(() {
    repository = MockPrescriptionsRepository();
    useCase = CheckDrugInteractionsUseCase(repository);
  });

  test('returns interactions reported by the repository', () {
    const interaction = DrugInteraction(
      medicationA: 'warfarin',
      medicationB: 'aspirin',
      severity: InteractionSeverity.severe,
      description: 'Bleeding risk',
    );
    when(() => repository.checkInteractions(['warfarin', 'aspirin']))
        .thenReturn([interaction]);

    final result = useCase(['warfarin', 'aspirin']);

    expect(result, [interaction]);
  });

  test('returns an empty list when nothing interacts', () {
    when(() => repository.checkInteractions(['metformin'])).thenReturn([]);

    final result = useCase(['metformin']);

    expect(result, isEmpty);
  });
}
