import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/entities/staff_unavailability.dart';

abstract class SchedulingDataSource {
  bool hasConflict(String staffId, DateTime start, DateTime end);

  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek);

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

  double weeklyOvertimeHours(String staffId, DateTime anyDayInWeek, {double weeklyThreshold = 40});

  Future<List<StaffNotification>> getNotifications(String staffId);
}
