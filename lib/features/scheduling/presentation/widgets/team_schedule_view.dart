import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/shift.dart';
import '../providers/scheduling_providers.dart';
import 'create_shift_sheet.dart';

/// Doctor-only admin view: the whole clinic's week, workload per staff
/// member, and pending leave approvals — the counterpart to Staff
/// Management, which handles who exists rather than when they work.
class TeamScheduleView extends ConsumerWidget {
  const TeamScheduleView({super.key, required this.clinicId});

  final String clinicId;

  Future<void> _decideLeave(WidgetRef ref, LeaveRequest leave, LeaveStatus status) async {
    final decider = ref.read(currentUserProvider);
    if (decider == null) return;
    await ref
        .read(schedulingRepositoryProvider)
        .decideLeave(leave.id, status: status, decidedBy: decider.id);
    ref.read(schedulingRevisionProvider.notifier).state++;
  }

  Future<void> _updateStatus(WidgetRef ref, Shift shift, ShiftStatus status) async {
    await ref.read(schedulingRepositoryProvider).updateShiftStatus(shift.id, status);
    ref.read(schedulingRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = DateTime.now();
    final staff = ref
        .watch(mockDatabaseProvider)
        .users
        .where((u) => u.clinicId == clinicId && (u.role == UserRole.doctor || u.role == UserRole.pharmacist))
        .toList();
    final shifts = ref.watch(clinicShiftsProvider(clinicId));
    final leaveRequests = ref.watch(clinicLeaveRequestsProvider(clinicId));
    final pendingLeave = leaveRequests.where((l) => l.status == LeaveStatus.pending).toList();

    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekShifts = shifts.where((s) => !s.start.isBefore(weekStart) && s.start.isBefore(weekEnd)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showCreateShiftSheet(context, ref, clinicId),
            style: FilledButton.styleFrom(backgroundColor: colors.clinicianAccent),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Shift'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Workload this week', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final person in staff) ...[
          _WorkloadRow(staff: person),
          const SizedBox(height: 8),
        ],
        if (pendingLeave.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Pending leave requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final leave in pendingLeave) ...[
            _PendingLeaveRow(
              leave: leave,
              staffName: _nameFor(staff, leave.staffId),
              onApprove: () => _decideLeave(ref, leave, LeaveStatus.approved),
              onDeny: () => _decideLeave(ref, leave, LeaveStatus.denied),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 20),
        Text('This week', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (weekShifts.isEmpty)
          const EmptyStateView(title: 'No shifts scheduled this week', icon: Icons.calendar_today_outlined)
        else
          for (final shift in weekShifts) ...[
            _TeamShiftRow(
              shift: shift,
              staffName: _nameFor(staff, shift.staffId),
              onComplete: () => _updateStatus(ref, shift, ShiftStatus.completed),
              onCancel: () => _updateStatus(ref, shift, ShiftStatus.cancelled),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  String _nameFor(List<AppUser> staff, String staffId) {
    for (final s in staff) {
      if (s.id == staffId) return s.fullName;
    }
    return 'Staff';
  }
}

class _WorkloadRow extends ConsumerWidget {
  const _WorkloadRow({required this.staff});

  final AppUser staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = DateTime.now();
    final hours = ref.watch(weeklyScheduledHoursProvider((staffId: staff.id, week: now)));
    final overtime = ref.watch(weeklyOvertimeHoursProvider((staffId: staff.id, week: now)));

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
                Text(staff.fullName, style: Theme.of(context).textTheme.titleSmall),
                Text(staff.role.label, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
              ],
            ),
          ),
          Text('${hours.toStringAsFixed(1)}h', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
          if (overtime > 0) ...[
            const SizedBox(width: 8),
            StatusBadge(label: '+${overtime.toStringAsFixed(1)}h OT', tone: StatusTone.danger),
          ],
        ],
      ),
    );
  }
}

class _PendingLeaveRow extends StatelessWidget {
  const _PendingLeaveRow({
    required this.leave,
    required this.staffName,
    required this.onApprove,
    required this.onDeny,
  });

  final LeaveRequest leave;
  final String staffName;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(staffName, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            '${DateFormatters.short(leave.startDate)} - ${DateFormatters.short(leave.endDate)} · ${leave.reason}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDeny, child: const Text('Deny')),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(backgroundColor: colors.success),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamShiftRow extends StatelessWidget {
  const _TeamShiftRow({
    required this.shift,
    required this.staffName,
    required this.onComplete,
    required this.onCancel,
  });

  final Shift shift;
  final String staffName;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = switch (shift.status) {
      ShiftStatus.scheduled => StatusTone.info,
      ShiftStatus.completed => StatusTone.success,
      ShiftStatus.missed => StatusTone.danger,
      ShiftStatus.cancelled => StatusTone.neutral,
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
                Text(staffName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatters.short(shift.start)} · ${DateFormatters.time(shift.start)} - ${DateFormatters.time(shift.end)}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge(label: shift.status.label, tone: tone),
          if (shift.status == ShiftStatus.scheduled) ...[
            IconButton(
              onPressed: onComplete,
              icon: Icon(Icons.check_circle_outline, size: 20, color: colors.success),
              tooltip: 'Mark completed',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onCancel,
              icon: Icon(Icons.cancel_outlined, size: 20, color: colors.danger),
              tooltip: 'Cancel shift',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
