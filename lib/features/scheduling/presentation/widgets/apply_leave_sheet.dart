import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../providers/scheduling_providers.dart';

/// Leave form. The leave is granted on submission and the booking system
/// is updated in the same step — the doctor is the clinic admin, so a
/// pending state would have nobody to approve it.
///
/// (The repository still takes an `autoApprove` flag, so a request-then-
/// approve flow can be reintroduced for other roles without touching the
/// data layer.)
///
/// Returns the number of appointments that were cancelled by the leave, or
/// `null` if the sheet was dismissed.
Future<int?> showApplyLeaveSheet(BuildContext context, WidgetRef ref, String staffId) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ApplyLeaveSheet(staffId: staffId),
  );
}

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet({required this.staffId});

  final String staffId;

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  final _reasonController = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await ref.read(applyLeaveUseCaseProvider).call(
          staffId: widget.staffId,
          startDate: _start,
          endDate: _end,
          reason: _reasonController.text.trim(),
        );

    ref.read(schedulingRevisionProvider.notifier).state++;
    ref.read(appointmentsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(result.cancelledAppointments.length);
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dayCount = _end.difference(DateTime(_start.year, _start.month, _start.day)).inDays + 1;
    final clashes = ref.watch(
      appointmentsInLeaveRangeProvider((doctorId: widget.staffId, start: _start, end: _end)),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Apply for Leave', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Approved as soon as you submit — patients will not be offered any slot '
                'with you on these dates.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStart,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'From',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(_fmt(_start), style: const TextStyle(fontSize: 13.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEnd,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'To',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(_fmt(_end), style: const TextStyle(fontSize: 13.5)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$dayCount ${dayCount == 1 ? 'day' : 'days'} off',
                style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (clashes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.event_busy_outlined, size: 18, color: colors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${clashes.length} booked ${clashes.length == 1 ? 'appointment' : 'appointments'} '
                              'in this window',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'They will be cancelled when the leave is applied: '
                              '${clashes.take(3).map((a) => DateFormatters.short(a.scheduledAt)).join(', ')}'
                              '${clashes.length > 3 ? '…' : ''}',
                              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'Apply for Leave', onPressed: _save, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
