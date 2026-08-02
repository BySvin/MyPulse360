import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../domain/entities/time_slot.dart';
import '../providers/appointments_providers.dart';
import '../widgets/month_calendar.dart';
import '../widgets/time_slot_grid.dart';

const _appointmentTypes = ['General Checkup', 'Follow-up', 'New Patient', 'Diabetes Follow-up'];
const _customType = 'Custom';

/// P6 — Book Appointment: month calendar + slot grid + booking summary,
/// matching the §4.1.6B reference (calendar + slot grid with
/// booked/selected/disabled states).
class BookAppointmentPage extends ConsumerStatefulWidget {
  const BookAppointmentPage({super.key});

  @override
  ConsumerState<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends ConsumerState<BookAppointmentPage> {
  late DateTime _selectedDate;
  TimeSlot? _selectedSlot;
  String _type = _appointmentTypes.first;
  final _customTypeController = TextEditingController();
  bool _notifyMe = true;
  bool _booking = false;

  bool get _isCustom => _type == _customType;
  bool get _customTypeMissing => _isCustom && _customTypeController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _book(String doctorId, String patientId) async {
    final slot = _selectedSlot;
    if (slot == null || _customTypeMissing) return;
    final customText = _customTypeController.text.trim();
    setState(() => _booking = true);
    await ref.read(appointmentsRepositoryProvider).book(
          patientId: patientId,
          doctorId: doctorId,
          scheduledAt: slot.dateTime,
          appointmentType: _isCustom ? customText : _type,
          reasonForVisit: _isCustom ? customText : null,
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
    final doctor = ref.watch(authRepositoryProvider).getUserById(doctorId);
    final clinics = ref.watch(mockDatabaseProvider).clinics;
    final clinicName = clinics.isEmpty ? 'MyPulse360 Clinic' : clinics.first.name;

    final rawSlots = ref.watch(availableSlotsProvider((doctorId: doctorId, date: _selectedDate)));
    final openCount = rawSlots.where((s) => !s.isDisabled).length;
    final slots = rawSlots.map((s) {
      final selected = _selectedSlot != null && s.dateTime == _selectedSlot!.dateTime;
      return s.copyWith(isSelected: selected);
    }).toList();

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Select a time'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${doctor?.fullName ?? 'Doctor'} · ${_isCustom ? "Custom visit" : _type}',
              style: TextStyle(fontSize: 12.5, color: colors.patientAccentText, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Text('Appointment type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in [..._appointmentTypes, _customType])
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
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: !_isCustom
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _customTypeController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Skin rash follow-up',
                          labelText: 'Describe your appointment',
                        ),
                      ).animate().fadeIn(duration: 200.ms),
                    ),
            ),
            const SizedBox(height: 20),
            MonthCalendar(
              doctorId: doctorId,
              selectedDate: _selectedDate,
              onSelected: (d) => setState(() {
                _selectedDate = d;
                _selectedSlot = null;
              }),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormatters.full(_selectedDate), style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '$openCount of ${rawSlots.length} slots open',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
              ],
            ),
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
            if (_selectedSlot != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUMMARY',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: colors.textTertiary),
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(label: 'Doctor', value: doctor?.fullName ?? 'Doctor'),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'When',
                      value: '${DateFormatters.short(_selectedDate)}, ${DateFormatters.time(_selectedSlot!.dateTime)}',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(label: 'Where', value: clinicName),
                  ],
                ),
              ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _notifyMe,
                onChanged: (v) => setState(() => _notifyMe = v ?? true),
                title: const Text('Notify me 1 hour before', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: colors.patientAccent,
              ),
            ],
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Confirm Booking',
              onPressed: _selectedSlot == null || _customTypeMissing ? null : () => _book(doctorId, user.id),
              loading: _booking,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
      ],
    );
  }
}
