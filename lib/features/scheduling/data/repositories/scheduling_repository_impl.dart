import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/entities/staff_unavailability.dart';
import '../../domain/repositories/scheduling_repository.dart';
import '../datasources/scheduling_datasource.dart';

class SchedulingRepositoryImpl implements SchedulingRepository {
  SchedulingRepositoryImpl(this._dataSource);

  final SchedulingDataSource _dataSource;

  @override
  bool hasConflict(String staffId, DateTime start, DateTime end) =>
      _dataSource.hasConflict(staffId, start, end);

  @override
  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek) =>
      _dataSource.weeklyScheduledHours(staffId, anyDayInWeek);

  @override
  List<AppUser> suggestStaff({
    required UserRole role,
    required String clinicId,
    required DateTime start,
    required DateTime end,
  }) =>
      _dataSource.suggestStaff(role: role, clinicId: clinicId, start: start, end: end);

  @override
  Future<List<LeaveRequest>> getLeaveRequests(String clinicId) => _dataSource.getLeaveRequests(clinicId);

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForStaff(String staffId) =>
      _dataSource.getLeaveRequestsForStaff(staffId);

  @override
  Future<LeaveRequest> requestLeave({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    bool autoApprove = false,
  }) =>
      _dataSource.requestLeave(
        staffId: staffId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        autoApprove: autoApprove,
      );

  @override
  Future<void> decideLeave(String leaveId, {required LeaveStatus status, required String decidedBy}) =>
      _dataSource.decideLeave(leaveId, status: status, decidedBy: decidedBy);

  @override
  Future<void> cancelLeave(String leaveId) => _dataSource.cancelLeave(leaveId);

  @override
  Future<List<StaffUnavailability>> getUnavailability(String staffId) => _dataSource.getUnavailability(staffId);

  @override
  Future<void> markUnavailable({required String staffId, required DateTime date, String? reason}) =>
      _dataSource.markUnavailable(staffId: staffId, date: date, reason: reason);

  @override
  Future<void> clearUnavailability(String id) => _dataSource.clearUnavailability(id);

  @override
  Future<AttendanceRecord?> getOpenAttendance(String staffId) => _dataSource.getOpenAttendance(staffId);

  @override
  Future<List<AttendanceRecord>> getAttendanceForStaff(String staffId) => _dataSource.getAttendanceForStaff(staffId);

  @override
  Future<AttendanceRecord> clockIn({required String staffId}) =>
      _dataSource.clockIn(staffId: staffId);

  @override
  Future<void> clockOut(String attendanceId) => _dataSource.clockOut(attendanceId);

  @override
  double weeklyOvertimeHours(String staffId, DateTime anyDayInWeek, {double weeklyThreshold = 40}) =>
      _dataSource.weeklyOvertimeHours(staffId, anyDayInWeek, weeklyThreshold: weeklyThreshold);

  @override
  Future<List<StaffNotification>> getNotifications(String staffId) => _dataSource.getNotifications(staffId);
}
