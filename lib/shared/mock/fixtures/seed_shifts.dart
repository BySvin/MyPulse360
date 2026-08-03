import '../../../features/scheduling/domain/entities/shift.dart';
import '../mock_ids.dart';

/// A Mon-Fri week of 9-5 shifts for the two seeded staff members so the
/// Schedule screens (workload, overtime, calendar) have real data on first
/// load instead of an empty state. Days before today are marked completed.
List<Shift> seedShifts() {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final today = DateTime(now.year, now.month, now.day);

  final shifts = <Shift>[];
  var counter = 0;
  for (final staffId in [MockIds.drAhmedUserId, MockIds.fatimaUserId]) {
    for (var i = 0; i < 5; i++) {
      final day = monday.add(Duration(days: i));
      final isPast = day.isBefore(today);
      shifts.add(
        Shift(
          id: 'shift-seed-${counter++}',
          staffId: staffId,
          clinicId: MockIds.defaultClinicId,
          start: DateTime(day.year, day.month, day.day, 9),
          end: DateTime(day.year, day.month, day.day, 17),
          status: isPast ? ShiftStatus.completed : ShiftStatus.scheduled,
        ),
      );
    }
  }
  return shifts;
}
