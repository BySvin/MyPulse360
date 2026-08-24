import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/appointments/data/datasources/mock_appointments_datasource.dart';
import 'package:mypulse360/features/scheduling/domain/entities/leave_request.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

/// Exercises the doctor-leave integration added to slot generation — a
/// day covered by the doctor's approved leave should show zero real
/// availability and be flagged distinctly from a merely fully-booked day.
void main() {
  late MockDatabase db;
  late MockAppointmentsDataSource dataSource;

  setUp(() {
    db = MockDatabase();
    dataSource = MockAppointmentsDataSource(db);
  });

  test(
    'every slot is disabled and flagged on-leave when leave is approved for that day',
    () async {
      final leaveDay = DateTime.now().add(const Duration(days: 10));
      db.leaveRequests.add(
        LeaveRequest(
          id: 'leave-1',
          staffId: MockIds.drAhmedUserId,
          startDate: leaveDay,
          endDate: leaveDay,
          reason: 'Vacation',
          status: LeaveStatus.approved,
          requestedAt: DateTime.now(),
        ),
      );

      final slots = await dataSource.getAvailableSlots(
        doctorId: MockIds.drAhmedUserId,
        date: leaveDay,
      );

      expect(slots, isNotEmpty);
      expect(slots.every((s) => s.isDisabled), isTrue);
      expect(slots.every((s) => s.isDoctorOnLeave), isTrue);
    },
  );

  test(
    'a pending (not yet approved) leave request does not block slots',
    () async {
      final leaveDay = DateTime.now().add(const Duration(days: 11));
      db.leaveRequests.add(
        LeaveRequest(
          id: 'leave-2',
          staffId: MockIds.drAhmedUserId,
          startDate: leaveDay,
          endDate: leaveDay,
          reason: 'Vacation',
          status: LeaveStatus.pending,
          requestedAt: DateTime.now(),
        ),
      );

      final slots = await dataSource.getAvailableSlots(
        doctorId: MockIds.drAhmedUserId,
        date: leaveDay,
      );

      expect(slots.any((s) => s.isDoctorOnLeave), isFalse);
      expect(slots.any((s) => !s.isDisabled), isTrue);
    },
  );

  test(
    'approved leave for a different doctor does not affect this one',
    () async {
      final leaveDay = DateTime.now().add(const Duration(days: 12));
      db.leaveRequests.add(
        LeaveRequest(
          id: 'leave-3',
          staffId: MockIds.fatimaUserId,
          startDate: leaveDay,
          endDate: leaveDay,
          reason: 'Vacation',
          status: LeaveStatus.approved,
          requestedAt: DateTime.now(),
        ),
      );

      final slots = await dataSource.getAvailableSlots(
        doctorId: MockIds.drAhmedUserId,
        date: leaveDay,
      );

      expect(slots.any((s) => s.isDoctorOnLeave), isFalse);
    },
  );

  test('a day outside the approved leave range is unaffected', () async {
    final leaveStart = DateTime.now().add(const Duration(days: 20));
    final leaveEnd = DateTime.now().add(const Duration(days: 22));
    db.leaveRequests.add(
      LeaveRequest(
        id: 'leave-4',
        staffId: MockIds.drAhmedUserId,
        startDate: leaveStart,
        endDate: leaveEnd,
        reason: 'Vacation',
        status: LeaveStatus.approved,
        requestedAt: DateTime.now(),
      ),
    );

    final dayAfterLeave = leaveEnd.add(const Duration(days: 1));
    final slots = await dataSource.getAvailableSlots(
      doctorId: MockIds.drAhmedUserId,
      date: dayAfterLeave,
    );

    expect(slots.any((s) => s.isDoctorOnLeave), isFalse);
  });
}
