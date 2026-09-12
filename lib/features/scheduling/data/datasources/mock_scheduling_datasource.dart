import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/entities/staff_unavailability.dart';
import 'scheduling_datasource.dart';

class MockSchedulingDataSource implements SchedulingDataSource {
  MockSchedulingDataSource(this._db);

  final MockDatabase _db;

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime _endOfWeek(DateTime date) => _startOfWeek(date).add(const Duration(days: 7));

  String _shortDate(DateTime d) => '${d.month}/${d.day}';

  @override
  bool hasConflict(String staffId, DateTime start, DateTime end) {
    // No shift conflict check — shifts are no longer tracked.
    return false;
  }

  @override
  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek) {
    return 0.0;
  }

  @override
  List<AppUser> suggestStaff({
    required UserRole role,
    required String clinicId,
    required DateTime start,
    required DateTime end,
  }) {
    final dateOnly = DateTime(start.year, start.month, start.day);
    final candidates = _db.users
        .where((u) => u.role == role && u.clinicId == clinicId && u.isActive)
        .where((u) => !_db.unavailability.any((un) => un.staffId == u.id && un.isSameDay(dateOnly)))
        .where(
          (u) => !_db.leaveRequests.any(
            (l) => l.staffId == u.id && l.status == LeaveStatus.approved && l.coversDate(dateOnly),
          ),
        )
        .toList();
    return candidates;
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequests(String clinicId) async {
    final staffIds = _db.users.where((u) => u.clinicId == clinicId).map((u) => u.id).toSet();
    final list = _db.leaveRequests.where((l) => staffIds.contains(l.staffId)).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForStaff(String staffId) async {
    final list = _db.leaveRequests.where((l) => l.staffId == staffId).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  @override
  Future<LeaveRequest> requestLeave({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    bool autoApprove = false,
  }) async {
    await simulateLatency();
    final now = DateTime.now();
    final request = LeaveRequest(
      id: generateId(),
      staffId: staffId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: autoApprove ? LeaveStatus.approved : LeaveStatus.pending,
      requestedAt: now,
      decidedBy: autoApprove ? staffId : null,
      decidedAt: autoApprove ? now : null,
    );
    _db.leaveRequests.add(request);
    if (autoApprove) {
      _db.staffNotifications.add(
        StaffNotification(
          id: generateId(),
          staffId: staffId,
          message: 'Leave approved for ${_shortDate(startDate)}-${_shortDate(endDate)}. '
              'Patients can no longer book you on those dates.',
          sentAt: now,
        ),
      );
    }
    return request;
  }

  @override
  Future<void> decideLeave(String leaveId, {required LeaveStatus status, required String decidedBy}) async {
    await simulateLatency();
    final i = _db.leaveRequests.indexWhere((l) => l.id == leaveId);
    if (i == -1) throw StateError('Leave request not found');
    final updated = _db.leaveRequests[i].copyWith(
      status: status,
      decidedBy: decidedBy,
      decidedAt: DateTime.now(),
    );
    _db.leaveRequests[i] = updated;
    _db.staffNotifications.add(
      StaffNotification(
        id: generateId(),
        staffId: updated.staffId,
        message: 'Your leave request (${_shortDate(updated.startDate)}-${_shortDate(updated.endDate)}) '
            'was ${status.label.toLowerCase()}.',
        sentAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> cancelLeave(String leaveId) async {
    await simulateLatency();
    _db.leaveRequests.removeWhere((l) => l.id == leaveId);
  }

  @override
  Future<List<StaffUnavailability>> getUnavailability(String staffId) async {
    final list = _db.unavailability.where((u) => u.staffId == staffId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  @override
  Future<void> markUnavailable({required String staffId, required DateTime date, String? reason}) async {
    await simulateLatency();
    _db.unavailability.add(
      StaffUnavailability(
        id: generateId(),
        staffId: staffId,
        date: DateTime(date.year, date.month, date.day),
        reason: reason,
      ),
    );
  }

  @override
  Future<void> clearUnavailability(String id) async {
    await simulateLatency();
    _db.unavailability.removeWhere((u) => u.id == id);
  }

  @override
  Future<AttendanceRecord?> getOpenAttendance(String staffId) async {
    for (final a in _db.attendanceRecords) {
      if (a.staffId == staffId && a.isOpen) return a;
    }
    return null;
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForStaff(String staffId) async {
    final list = _db.attendanceRecords.where((a) => a.staffId == staffId).toList()
      ..sort((a, b) => b.clockInAt.compareTo(a.clockInAt));
    return list;
  }

  @override
  Future<AttendanceRecord> clockIn({required String staffId}) async {
    await simulateLatency();
    final existing = await getOpenAttendance(staffId);
    if (existing != null) return existing;
    final record = AttendanceRecord(
      id: generateId(),
      staffId: staffId,
      clockInAt: DateTime.now(),
    );
    _db.attendanceRecords.add(record);
    return record;
  }

  @override
  Future<void> clockOut(String attendanceId) async {
    await simulateLatency();
    final i = _db.attendanceRecords.indexWhere((a) => a.id == attendanceId);
    if (i == -1) throw StateError('Attendance record not found');
    _db.attendanceRecords[i] = _db.attendanceRecords[i].copyWith(clockOutAt: DateTime.now());
  }

  @override
  double weeklyOvertimeHours(String staffId, DateTime anyDayInWeek, {double weeklyThreshold = 40}) {
    final weekStart = _startOfWeek(anyDayInWeek);
    final weekEnd = _endOfWeek(anyDayInWeek);
    var minutes = 0;
    for (final a in _db.attendanceRecords) {
      if (a.staffId != staffId) continue;
      if (a.clockInAt.isBefore(weekStart) || !a.clockInAt.isBefore(weekEnd)) continue;
      final worked = a.workedDuration;
      if (worked != null) minutes += worked.inMinutes;
    }
    final hours = minutes / 60.0;
    final overtime = hours - weeklyThreshold;
    return overtime > 0 ? overtime : 0;
  }

  @override
  Future<List<StaffNotification>> getNotifications(String staffId) async {
    final list = _db.staffNotifications.where((n) => n.staffId == staffId).toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return list;
  }
}
