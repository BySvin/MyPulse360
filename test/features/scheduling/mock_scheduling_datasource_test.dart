import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/features/scheduling/data/datasources/mock_scheduling_datasource.dart';
import 'package:mypulse360/features/scheduling/domain/entities/leave_request.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

/// Exercises the scheduling rules that remain after shifts were removed —
/// leave/unavailability exclusion in staff suggestions, attendance-based
/// overtime, and the full leave lifecycle.
void main() {
  late MockDatabase db;
  late MockSchedulingDataSource dataSource;

  // A Monday, so weekly-hours math is unambiguous regardless of when the
  // test suite runs.
  final monday = DateTime(2026, 1, 5);

  setUp(() {
    db = MockDatabase();
    dataSource = MockSchedulingDataSource(db);
  });

  group('suggestStaff', () {
    test('excludes staff on approved leave that day', () async {
      final leave = await dataSource.requestLeave(
        staffId: MockIds.fatimaUserId,
        startDate: DateTime(2026, 1, 12),
        endDate: DateTime(2026, 1, 12),
        reason: 'Personal',
      );
      await dataSource.decideLeave(leave.id, status: LeaveStatus.approved, decidedBy: MockIds.drAhmedUserId);

      final candidates = dataSource.suggestStaff(
        role: UserRole.pharmacist,
        clinicId: MockIds.defaultClinicId,
        start: DateTime(2026, 1, 12, 9),
        end: DateTime(2026, 1, 12, 17),
      );
      expect(candidates.map((u) => u.id), isNot(contains(MockIds.fatimaUserId)));
    });

    test('excludes staff marked unavailable that day', () async {
      await dataSource.markUnavailable(staffId: MockIds.fatimaUserId, date: DateTime(2026, 1, 13));

      final candidates = dataSource.suggestStaff(
        role: UserRole.pharmacist,
        clinicId: MockIds.defaultClinicId,
        start: DateTime(2026, 1, 13, 9),
        end: DateTime(2026, 1, 13, 17),
      );
      expect(candidates.map((u) => u.id), isNot(contains(MockIds.fatimaUserId)));
    });
  });

  group('attendance and overtime', () {
    test('clock in then clock out produces a closed record with worked duration', () async {
      final record = await dataSource.clockIn(staffId: MockIds.fatimaUserId);
      expect(record.isOpen, isTrue);
      expect(await dataSource.getOpenAttendance(MockIds.fatimaUserId), isNotNull);

      await dataSource.clockOut(record.id);
      expect(await dataSource.getOpenAttendance(MockIds.fatimaUserId), isNull);
      final closed = (await dataSource.getAttendanceForStaff(MockIds.fatimaUserId)).first;
      expect(closed.workedDuration, isNotNull);
    });

    test('a second clock-in while already open returns the same open record', () async {
      final first = await dataSource.clockIn(staffId: MockIds.fatimaUserId);
      final second = await dataSource.clockIn(staffId: MockIds.fatimaUserId);
      expect(second.id, first.id);
      expect(await dataSource.getAttendanceForStaff(MockIds.fatimaUserId), hasLength(1));
    });

    test('weekly overtime is zero when under the threshold', () {
      expect(dataSource.weeklyOvertimeHours(MockIds.fatimaUserId, monday), 0);
    });
  });

  group('leave requests', () {
    test('decideLeave stamps who decided and notifies the requester', () async {
      final leave = await dataSource.requestLeave(
        staffId: MockIds.fatimaUserId,
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 3),
        reason: 'Vacation',
      );

      await dataSource.decideLeave(leave.id, status: LeaveStatus.approved, decidedBy: MockIds.drAhmedUserId);

      final updated = (await dataSource.getLeaveRequestsForStaff(MockIds.fatimaUserId))
          .firstWhere((l) => l.id == leave.id);
      expect(updated.status, LeaveStatus.approved);
      expect(updated.decidedBy, MockIds.drAhmedUserId);
      expect(await dataSource.getNotifications(MockIds.fatimaUserId), isNotEmpty);
    });

    test('autoApprove files the leave as already approved and self-decided', () async {
      final leave = await dataSource.requestLeave(
        staffId: MockIds.drAhmedUserId,
        startDate: DateTime(2026, 3, 2),
        endDate: DateTime(2026, 3, 4),
        reason: 'Conference',
        autoApprove: true,
      );

      expect(leave.status, LeaveStatus.approved);
      expect(leave.decidedBy, MockIds.drAhmedUserId, reason: 'the doctor is their own approver');
      expect(leave.decidedAt, isNotNull);
      expect(await dataSource.getNotifications(MockIds.drAhmedUserId), isNotEmpty);
    });

    test('cancelLeave removes the record so the days reopen', () async {
      final leave = await dataSource.requestLeave(
        staffId: MockIds.drAhmedUserId,
        startDate: DateTime(2026, 3, 9),
        endDate: DateTime(2026, 3, 9),
        reason: 'Personal',
        autoApprove: true,
      );

      await dataSource.cancelLeave(leave.id);

      final ids = (await dataSource.getLeaveRequestsForStaff(MockIds.drAhmedUserId)).map((l) => l.id);
      expect(ids, isNot(contains(leave.id)));
    });
  });
}