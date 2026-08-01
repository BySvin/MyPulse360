// Placeholder smoke test — replaced by real unit/widget tests in the tests
// phase of the implementation plan (see plan file, phase 8).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sanity: MaterialApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('MyPulse360'))),
    );
    expect(find.text('MyPulse360'), findsOneWidget);
  });
}
