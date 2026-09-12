import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../entities/attendance_record.dart';
import '../entities/leave_request.dart';
import '../entities/staff_notification.dart';
import '../entities/staff_unavailability.dart';

abstract class SchedulingRepository {
  bool hasConflict(String staffId, DateTime start, DateTime end);

  /// Total scheduled hours for [staffId] in the Mon-Sun week containing
  /// [anyDayInWeek].
  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek);

  /// Candidates of [role] at [clinicId] able to cover [start]-[end] —
  /// excludes anyone with approved leave or a marked unavailable day
  /// overlapping the period — ranked fewest-hours-this-week first.
  List<AppUser> suggestStaff({
    required UserRole role,
    required String clinicId,
    required DateTime start,
    required DateTime end,
  });

  Future<List<LeaveRequest>> getLeaveRequests(String clinicId);

  Future<List<LeaveRequest>> getLeaveRequestsForStaff(String staffId);

  /// [autoApprove] files the request as already approved and self-decided —
  /// the doctor's Apply Leave flow, where the doctor is the clinic admin and
  /// so has nobody above them to approve it.
  Future<LeaveRequest> requestLeave({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    bool autoApprove = false,
  });

  Future<void> decideLeave(String leaveId, {required LeaveStatus status, required String decidedBy});

  /// Withdraws a leave record entirely, which reopens the days it covered
  /// for patient booking.
  Future<void> cancelLeave(String leaveId);

  Future<List<StaffUnavailability>> getUnavailability(String staffId);

  Future<void> markUnavailable({required String staffId, required DateTime date, String? reason});

  Future<void> clearUnavailability(String id);

  Future<AttendanceRecord?> getOpenAttendance(String staffId);

  Future<List<AttendanceRecord>> getAttendanceForStaff(String staffId);

  Future<AttendanceRecord> clockIn({required String staffId});

  Future<void> clockOut(String attendanceId);

  /// Hours actually worked (via clock in/out) beyond [weeklyThreshold] in
  /// the Mon-Sun week containing [anyDayInWeek] — real attendance, not a
  /// restatement of the schedule.
  double weeklyOvertimeHours(String staffId, DateTime anyDayInWeek, {double weeklyThreshold});

  Future<List<StaffNotification>> getNotifications(String staffId);
}
