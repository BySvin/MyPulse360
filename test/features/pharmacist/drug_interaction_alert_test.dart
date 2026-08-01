import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/pharmacist/presentation/widgets/drug_interaction_alert.dart';
import 'package:mypulse360/features/prescriptions/domain/entities/drug_interaction.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  testWidgets('renders nothing when there are no interactions', (tester) async {
    await tester.pumpWidget(wrap(const DrugInteractionAlert(interactions: [])));

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('Interaction check'), findsNothing);
  });

  testWidgets('surfaces medication names and severity when interactions exist', (tester) async {
    const interaction = DrugInteraction(
      medicationA: 'warfarin',
      medicationB: 'aspirin',
      severity: InteractionSeverity.severe,
      description: 'Bleeding risk',
    );

    await tester.pumpWidget(wrap(const DrugInteractionAlert(interactions: [interaction])));

    expect(find.text('Interaction check'), findsOneWidget);
    expect(find.textContaining('Warfarin + Aspirin'), findsOneWidget);
    expect(find.text('Bleeding risk'), findsOneWidget);
  });
}
