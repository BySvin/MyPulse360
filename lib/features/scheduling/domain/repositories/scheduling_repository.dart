import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../entities/attendance_record.dart';
import '../entities/leave_request.dart';
import '../entities/shift.dart';
import '../entities/staff_notification.dart';
import '../entities/staff_unavailability.dart';

abstract class SchedulingRepository {
  List<Shift> getShiftsForClinic(String clinicId);

  List<Shift> getShiftsForStaff(String staffId);

  Future<Shift> createShift({
    required String staffId,
    required String clinicId,
    required DateTime start,
    required DateTime end,
    String? notes,
  });

  Future<void> updateShiftStatus(String shiftId, ShiftStatus status);

  Future<void> deleteShift(String shiftId);

  bool hasConflict(String staffId, DateTime start, DateTime end, {String? excludeShiftId});

  /// Total scheduled hours for [staffId] in the Mon-Sun week containing
  /// [anyDayInWeek].
  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek);

  /// Candidates of [role] at [clinicId] able to cover [start]-[end] —
  /// excludes anyone with a conflicting shift, approved leave, or a marked
  /// unavailable day overlapping the shift — ranked fewest-hours-this-week
  /// first ("performance-based"/"optimization" is this one explainable
  /// rule, not a black-box solver).
  List<AppUser> suggestStaff({
    required UserRole role,
    required String clinicId,
    required DateTime start,
    required DateTime end,
  });

  List<LeaveRequest> getLeaveRequests(String clinicId);

  List<LeaveRequest> getLeaveRequestsForStaff(String staffId);

  Future<LeaveRequest> requestLeave({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  });

  Future<void> decideLeave(String leaveId, {required LeaveStatus status, required String decidedBy});

  List<StaffUnavailability> getUnavailability(String staffId);

  Future<void> markUnavailable({required String staffId, required DateTime date, String? reason});

  Future<void> clearUnavailability(String id);

  AttendanceRecord? getOpenAttendance(String staffId);

  List<AttendanceRecord> getAttendanceForStaff(String staffId);

  Future<AttendanceRecord> clockIn({required String staffId, String? shiftId});

  Future<void> clockOut(String attendanceId);

  /// Hours actually worked (via clock in/out) beyond [weeklyThreshold] in
  /// the Mon-Sun week containing [anyDayInWeek] — real attendance, not a
  /// restatement of the schedule.
  double weeklyOvertimeHours(String staffId, DateTime anyDayInWeek, {double weeklyThreshold});

  List<StaffNotification> getNotifications(String staffId);
}
