import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env/env.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/datasources/mock_scheduling_datasource.dart';
import '../../data/datasources/scheduling_datasource.dart';
import '../../data/datasources/supabase_scheduling_datasource.dart';
import '../../data/repositories/scheduling_repository_impl.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/repositories/scheduling_repository.dart';
import '../../domain/usecases/apply_leave_usecase.dart';

final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) {
  final SchedulingDataSource dataSource = Env.isMockMode
      ? MockSchedulingDataSource(ref.watch(mockDatabaseProvider))
      : SupabaseSchedulingDataSource(ref.watch(supabaseClientProvider));
  return SchedulingRepositoryImpl(dataSource);
});

/// Bumped after any mutating call so dependent providers re-read the mock
/// store — same pattern as every other feature's revision provider.
final schedulingRevisionProvider = StateProvider<int>((ref) => 0);

final clinicLeaveRequestsProvider =
    FutureProvider.family<List<LeaveRequest>, String>((ref, clinicId) async {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getLeaveRequests(clinicId);
});

final staffLeaveRequestsProvider =
    FutureProvider.family<List<LeaveRequest>, String>((ref, staffId) async {
  ref.watch(schedulingRevisionProvider);
  return ref
      .watch(schedulingRepositoryProvider)
      .getLeaveRequestsForStaff(staffId);
});

final applyLeaveUseCaseProvider = Provider<ApplyLeaveUseCase>((ref) {
  return ApplyLeaveUseCase(
    ref.watch(schedulingRepositoryProvider),
    ref.watch(appointmentsRepositoryProvider),
  );
});

/// Live appointments that a leave over [start]-[end] would displace — used
/// to warn before applying and to explain what was cancelled after.
final appointmentsInLeaveRangeProvider =
    FutureProvider.family<
      List<Appointment>,
      ({String doctorId, DateTime start, DateTime end})
    >((ref, args) {
      ref.watch(appointmentsRevisionProvider);
      ref.watch(schedulingRevisionProvider);
      return ref
          .watch(applyLeaveUseCaseProvider)
          .appointmentsInRange(
            doctorId: args.doctorId,
            startDate: args.start,
            endDate: args.end,
          );
    });

final openAttendanceProvider =
    FutureProvider.family<AttendanceRecord?, String>((ref, staffId) async {
  ref.watch(schedulingRevisionProvider);
  return ref.watch(schedulingRepositoryProvider).getOpenAttendance(staffId);
});

final staffAttendanceProvider =
    FutureProvider.family<List<AttendanceRecord>, String>(
      (ref, staffId) async {
        ref.watch(schedulingRevisionProvider);
        return ref
            .watch(schedulingRepositoryProvider)
            .getAttendanceForStaff(staffId);
      },
    );

final staffNotificationsProvider =
    FutureProvider.family<List<StaffNotification>, String>(
      (ref, staffId) async {
        ref.watch(schedulingRevisionProvider);
        return ref
            .watch(schedulingRepositoryProvider)
            .getNotifications(staffId);
      },
    );

final suggestStaffProvider =
    Provider.family<
      List<AppUser>,
      ({UserRole role, String clinicId, DateTime start, DateTime end})
    >((ref, args) {
      ref.watch(schedulingRevisionProvider);
      return ref
          .watch(schedulingRepositoryProvider)
          .suggestStaff(
            role: args.role,
            clinicId: args.clinicId,
            start: args.start,
            end: args.end,
          );
    });
