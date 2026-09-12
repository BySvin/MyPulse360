import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/leave_request.dart';
import '../providers/scheduling_providers.dart';
import '../widgets/apply_leave_sheet.dart';

/// Doctor's Apply Leave tab — the replacement for the old Schedule tab.
///
/// Leave taken here is granted immediately (the doctor is the clinic admin,
/// so there is nobody above them to approve it) and the booking system
/// follows from the same action: those dates stop offering slots to
/// patients, and anything already booked inside the window is cancelled.
class ApplyLeavePage extends ConsumerWidget {
  const ApplyLeavePage({super.key});

  Future<void> _apply(BuildContext context, WidgetRef ref, String staffId) async {
    final cancelled = await showApplyLeaveSheet(context, ref, staffId);
    if (cancelled == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cancelled == 0
              ? 'Leave approved. Patients can no longer book you on those dates.'
              : 'Leave approved. $cancelled booked '
                  '${cancelled == 1 ? 'appointment was' : 'appointments were'} cancelled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final today = DateTime.now();
    final leave =
        ref.watch(staffLeaveRequestsProvider(user.id)).valueOrNull ?? const [];
    final upcoming = leave.where((l) => !l.endDate.isBefore(DateTime(today.year, today.month, today.day))).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = leave.where((l) => l.endDate.isBefore(DateTime(today.year, today.month, today.day))).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Take Leave', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Book time off. Patients stop seeing you as available on those dates.',
                        style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _apply(context, ref, user.id),
                  style: FilledButton.styleFrom(backgroundColor: colors.clinicianAccent),
                  icon: const Icon(Icons.beach_access_outlined, size: 18),
                  label: const Text('Take Leave'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Upcoming leave', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              const EmptyStateView(
                title: 'No leave booked',
                message: 'Take leave and those dates close for patient booking straight away.',
                icon: Icons.beach_access_outlined,
              )
            else
              for (final l in upcoming) ...[
                _LeaveCard(leave: l, isUpcoming: true),
                const SizedBox(height: 10),
              ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Past leave', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final l in past) ...[
                _LeaveCard(leave: l, isUpcoming: false),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaveCard extends ConsumerWidget {
  const _LeaveCard({required this.leave, required this.isUpcoming});

  final LeaveRequest leave;
  final bool isUpcoming;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this leave?',
      message: 'Those dates open back up and patients will be able to book you again.',
      confirmLabel: 'Cancel leave',
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(schedulingRepositoryProvider).cancelLeave(leave.id);
    ref.read(schedulingRevisionProvider.notifier).state++;
    ref.read(appointmentsRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tone = switch (leave.status) {
      LeaveStatus.pending => StatusTone.warning,
      LeaveStatus.approved => StatusTone.success,
      LeaveStatus.denied => StatusTone.danger,
    };
    final days = leave.endDate.difference(leave.startDate).inDays + 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormatters.short(leave.startDate)} - ${DateFormatters.short(leave.endDate)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              StatusBadge(label: leave.status.label, tone: tone),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '$days ${days == 1 ? 'day' : 'days'}'
            '${leave.reason.isEmpty ? '' : ' · ${leave.reason}'}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          if (isUpcoming && leave.status == LeaveStatus.approved) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_busy_outlined, size: 14, color: colors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Closed for patient booking',
                    style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
                  ),
                ),
                TextButton(
                  onPressed: () => _cancel(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Cancel leave'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
