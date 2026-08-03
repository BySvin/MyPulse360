import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/shift.dart';
import '../providers/scheduling_providers.dart';
import 'request_leave_sheet.dart';

/// Personal schedule surface — used both as the pharmacist's whole Schedule
/// tab and as the "My Shifts" segment of the doctor's Schedule tab, so
/// every staff role gets the same clock in/out + leave-request experience.
class MyScheduleView extends ConsumerWidget {
  const MyScheduleView({super.key, required this.staffId, this.accentColor});

  final String staffId;
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accent = accentColor ?? colors.clinicianAccent;
    final now = DateTime.now();
    final shifts = ref.watch(staffShiftsProvider(staffId));
    final upcoming = shifts.where((s) => s.status == ShiftStatus.scheduled && !s.end.isBefore(now)).toList();
    final openAttendance = ref.watch(openAttendanceProvider(staffId));
    final scheduledHours = ref.watch(weeklyScheduledHoursProvider((staffId: staffId, week: now)));
    final overtimeHours = ref.watch(weeklyOvertimeHoursProvider((staffId: staffId, week: now)));
    final leaveRequests = ref.watch(staffLeaveRequestsProvider(staffId));
    final notifications = ref.watch(staffNotificationsProvider(staffId));

    final todaysShift = upcoming.where((s) => _isSameDay(s.start, now)).toList();
    final activeShiftId = todaysShift.isEmpty ? null : todaysShift.first.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _ClockCard(
          staffId: staffId,
          accent: accent,
          openAttendance: openAttendance,
          activeShiftId: activeShiftId,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Scheduled this week',
                value: '${scheduledHours.toStringAsFixed(1)}h',
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Overtime this week',
                value: '${overtimeHours.toStringAsFixed(1)}h',
                color: overtimeHours > 0 ? colors.danger : colors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming shifts', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => showRequestLeaveSheet(context, ref, staffId),
              icon: const Icon(Icons.beach_access_outlined, size: 18),
              label: const Text('Request Leave'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const EmptyStateView(title: 'No upcoming shifts', icon: Icons.calendar_today_outlined)
        else
          for (final shift in upcoming.take(10)) ...[
            _ShiftRow(shift: shift, accent: accent),
            const SizedBox(height: 8),
          ],
        if (leaveRequests.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Leave requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final leave in leaveRequests) ...[
            _LeaveRow(leave: leave),
            const SizedBox(height: 8),
          ],
        ],
        if (notifications.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'No SMS gateway is connected in this build — these are shown here instead of being texted.',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 8),
          for (final n in notifications.take(5)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sms_outlined, size: 16, color: colors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(n.message, style: TextStyle(fontSize: 12.5, color: colors.textPrimary))),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ClockCard extends ConsumerWidget {
  const _ClockCard({
    required this.staffId,
    required this.accent,
    required this.openAttendance,
    required this.activeShiftId,
  });

  final String staffId;
  final Color accent;
  final AttendanceRecord? openAttendance;
  final String? activeShiftId;

  Future<void> _clockIn(WidgetRef ref) async {
    await ref.read(schedulingRepositoryProvider).clockIn(staffId: staffId, shiftId: activeShiftId);
    ref.read(schedulingRevisionProvider.notifier).state++;
  }

  Future<void> _clockOut(WidgetRef ref, String attendanceId) async {
    await ref.read(schedulingRepositoryProvider).clockOut(attendanceId);
    ref.read(schedulingRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isClockedIn = openAttendance != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClockedIn ? accent : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: isClockedIn ? accent : colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClockedIn ? "You're clocked in" : 'Not clocked in',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isClockedIn ? Colors.white : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isClockedIn
                      ? 'Since ${DateFormatters.time(openAttendance!.clockInAt)}'
                      : 'Clock in when your shift starts',
                  style: TextStyle(
                    fontSize: 12,
                    color: isClockedIn ? Colors.white.withValues(alpha: 0.8) : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isClockedIn ? () => _clockOut(ref, openAttendance!.id) : () => _clockIn(ref),
            style: FilledButton.styleFrom(
              backgroundColor: isClockedIn ? Colors.white : accent,
              foregroundColor: isClockedIn ? accent : Colors.white,
            ),
            child: Text(isClockedIn ? 'Clock Out' : 'Clock In'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.shift, required this.accent});

  final Shift shift;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 32, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormatters.short(shift.start), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatters.time(shift.start)} - ${DateFormatters.time(shift.end)}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = switch (leave.status) {
      LeaveStatus.pending => StatusTone.warning,
      LeaveStatus.approved => StatusTone.success,
      LeaveStatus.denied => StatusTone.danger,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormatters.short(leave.startDate)} - ${DateFormatters.short(leave.endDate)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(leave.reason, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
          StatusBadge(label: leave.status.label, tone: tone),
        ],
      ),
    );
  }
}
