import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import '../providers/appointments_providers.dart';
import '../widgets/month_calendar.dart';
import '../widgets/time_slot_grid.dart';

/// Reuses the same calendar + slot-grid pattern as booking, pre-scoped to
/// the appointment's existing doctor.
class ReschedulePage extends ConsumerStatefulWidget {
  const ReschedulePage({super.key, required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<ReschedulePage> createState() => _ReschedulePageState();
}

class _ReschedulePageState extends ConsumerState<ReschedulePage> {
  late DateTime _selectedDate;
  TimeSlot? _selectedSlot;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _reschedule() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    setState(() => _saving = true);
    await ref.read(appointmentsRepositoryProvider).reschedule(widget.appointment.id, slot.dateTime);
    ref.read(appointmentsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final doctor = ref.watch(authRepositoryProvider).getUserById(widget.appointment.doctorId);
    final slots = ref
        .watch(availableSlotsProvider((doctorId: widget.appointment.doctorId, date: _selectedDate)))
        .map((s) {
      final selected = _selectedSlot != null && s.dateTime == _selectedSlot!.dateTime;
      return s.copyWith(isSelected: selected);
    }).toList();

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Reschedule'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select a new date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            MonthCalendar(
              doctorId: widget.appointment.doctorId,
              selectedDate: _selectedDate,
              onSelected: (d) => setState(() {
                _selectedDate = d;
                _selectedSlot = null;
              }),
            ),
            const SizedBox(height: 20),
            Text('Available times', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            AppCard(
              child: slots.every((s) => s.isDisabled)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        slots.any((s) => s.isDoctorOnLeave)
                            ? '${doctor?.fullName ?? 'Your doctor'} is on leave this day. Please choose another date.'
                            : 'No slots available this day. Try another date.',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    )
                  : TimeSlotGrid(
                      slots: slots,
                      onSelect: (s) => setState(() => _selectedSlot = s),
                    ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Confirm New Time',
              onPressed: _selectedSlot == null ? null : _reschedule,
              loading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
