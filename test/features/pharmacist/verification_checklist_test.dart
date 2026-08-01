import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/pharmacist/presentation/widgets/verification_checklist.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  testWidgets('renders every verification step', (tester) async {
    await tester.pumpWidget(
      wrap(VerificationChecklist(checked: const {}, onChanged: (_) {})),
    );

    for (final step in kVerificationSteps) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('tapping a step reports its index via onChanged', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(VerificationChecklist(checked: const {}, onChanged: (i) => tapped = i)),
    );

    await tester.tap(find.text(kVerificationSteps[1]));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('checked steps render as checked checkboxes', (tester) async {
    await tester.pumpWidget(
      wrap(VerificationChecklist(checked: const {0, 2}, onChanged: (_) {})),
    );

    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes[0].value, isTrue);
    expect(checkboxes[1].value, isFalse);
    expect(checkboxes[2].value, isTrue);
    expect(checkboxes[3].value, isFalse);
  });
}
