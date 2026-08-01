import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/config/theme/app_theme.dart';
import 'package:mypulse360/features/appointments/domain/entities/time_slot.dart';
import 'package:mypulse360/features/appointments/presentation/widgets/time_slot_grid.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  testWidgets('tapping an available slot reports it via onSelect', (tester) async {
    final available = TimeSlot(dateTime: DateTime(2026, 8, 1, 9));
    final booked = TimeSlot(dateTime: DateTime(2026, 8, 1, 9, 30), isBooked: true, isDisabled: true);
    TimeSlot? selected;

    await tester.pumpWidget(
      wrap(TimeSlotGrid(slots: [available, booked], onSelect: (s) => selected = s)),
    );

    await tester.tap(find.text('9:00 AM'));
    await tester.pump();

    expect(selected, available);
  });

  testWidgets('tapping a disabled slot does not report a selection', (tester) async {
    final booked = TimeSlot(dateTime: DateTime(2026, 8, 1, 9, 30), isBooked: true, isDisabled: true);
    TimeSlot? selected;

    await tester.pumpWidget(
      wrap(TimeSlotGrid(slots: [booked], onSelect: (s) => selected = s)),
    );

    await tester.tap(find.text('9:30 AM'));
    await tester.pump();

    expect(selected, isNull);
  });
}
