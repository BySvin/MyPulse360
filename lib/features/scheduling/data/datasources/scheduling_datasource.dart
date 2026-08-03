import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/shift.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/entities/staff_unavailability.dart';

abstract class SchedulingDataSource {
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

  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek);

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

  double weeklyOvertimeHours(String staffId, DateTime anyDayInWeek, {double weeklyThreshold = 40});

  List<StaffNotification> getNotifications(String staffId);
}
