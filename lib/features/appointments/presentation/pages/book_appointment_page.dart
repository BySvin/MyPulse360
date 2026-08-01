import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../domain/entities/time_slot.dart';
import '../providers/appointments_providers.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/time_slot_grid.dart';

const _appointmentTypes = ['General Checkup', 'Follow-up', 'New Patient', 'Diabetes Follow-up'];

/// P6 — Book Appointment: calendar + slot grid with
/// booked/selected/disabled states.
class BookAppointmentPage extends ConsumerStatefulWidget {
  const BookAppointmentPage({super.key});

  @override
  ConsumerState<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends ConsumerState<BookAppointmentPage> {
  late DateTime _selectedDate;
  TimeSlot? _selectedSlot;
  String _type = _appointmentTypes.first;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _book(String doctorId, String patientId) async {
    final slot = _selectedSlot;
    if (slot == null) return;
    setState(() => _booking = true);
    await ref.read(appointmentsRepositoryProvider).book(
          patientId: patientId,
          doctorId: doctorId,
          scheduledAt: slot.dateTime,
          appointmentType: _type,
        );
    ref.read(appointmentsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _booking = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final profile = ref.watch(patientProfileProvider(user.id));
    final doctorId = profile?.assignedDoctorId ?? 'user-dr-ahmed';

    final slots = ref.watch(availableSlotsProvider((doctorId: doctorId, date: _selectedDate))).map((s) {
      final selected = _selectedSlot != null && s.dateTime == _selectedSlot!.dateTime;
      return s.copyWith(isSelected: selected);
    }).toList();

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Book Appointment'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appointment type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _appointmentTypes)
                  ChoiceChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: colors.patientAccent,
                    labelStyle: TextStyle(color: _type == t ? Colors.white : colors.textPrimary),
                    backgroundColor: Theme.of(context).cardTheme.color,
                    side: BorderSide(color: colors.border),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Select a date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppointmentCalendar(
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
                        'No slots available this day. Try another date.',
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
              label: 'Confirm Booking',
              onPressed: _selectedSlot == null ? null : () => _book(doctorId, user.id),
              loading: _booking,
            ),
          ],
        ),
      ),
    );
  }
}
