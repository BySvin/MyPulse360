import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/datasources/mock_scheduling_datasource.dart';
import '../../data/repositories/scheduling_repository_impl.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/shift.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/repositories/scheduling_repository.dart';

final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) {
  return SchedulingRepositoryImpl(MockSchedulingDataSource(ref.watch(mockDatabaseProvider)));
});

/// Bumped after any mutating call so dependent providers re-read the mock
/// store — same pattern as every other feature's revision provider.
final schedulingRevisionProvider = StateProvider<int>((ref) => 0);

final clinicShiftsProvider = Provider.family<List<Shift>, String>((ref, clinicId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getShiftsForClinic(clinicId);
});

final staffShiftsProvider = Provider.family<List<Shift>, String>((ref, staffId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getShiftsForStaff(staffId);
});

final weeklyScheduledHoursProvider =
    Provider.family<double, ({String staffId, DateTime week})>((ref, args) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).weeklyScheduledHours(args.staffId, args.week);
});

final weeklyOvertimeHoursProvider =
    Provider.family<double, ({String staffId, DateTime week})>((ref, args) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).weeklyOvertimeHours(args.staffId, args.week);
});

final clinicLeaveRequestsProvider = Provider.family<List<LeaveRequest>, String>((ref, clinicId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getLeaveRequests(clinicId);
});

final staffLeaveRequestsProvider = Provider.family<List<LeaveRequest>, String>((ref, staffId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getLeaveRequestsForStaff(staffId);
});

final openAttendanceProvider = Provider.family<AttendanceRecord?, String>((ref, staffId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getOpenAttendance(staffId);
});

final staffAttendanceProvider = Provider.family<List<AttendanceRecord>, String>((ref, staffId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getAttendanceForStaff(staffId);
});

final staffNotificationsProvider = Provider.family<List<StaffNotification>, String>((ref, staffId) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getNotifications(staffId);
});

final suggestStaffProvider =
    Provider.family<List<AppUser>, ({UserRole role, String clinicId, DateTime start, DateTime end})>((ref, args) {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).suggestStaff(
        role: args.role,
        clinicId: args.clinicId,
        start: args.start,
        end: args.end,
      );
});
