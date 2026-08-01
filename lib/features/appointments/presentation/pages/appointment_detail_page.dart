import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/presentation/widgets/secondary_button.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/presentation/providers/doctor_providers.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';
import 'reschedule_page.dart';

/// Full detail view of a single appointment — doctor, clinic, date/time —
/// with the option to reschedule.
class AppointmentDetailPage extends ConsumerWidget {
  const AppointmentDetailPage({super.key, required this.appointmentId});

  final String appointmentId;

  StatusTone _tone(AppointmentStatus status) => switch (status) {
        AppointmentStatus.confirmed => StatusTone.success,
        AppointmentStatus.completed => StatusTone.info,
        AppointmentStatus.cancelled => StatusTone.danger,
        AppointmentStatus.scheduled => StatusTone.neutral,
        AppointmentStatus.inProgress => StatusTone.warning,
        AppointmentStatus.rescheduled => StatusTone.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final appointments = ref.watch(patientAppointmentsProvider(user.id));
    final matches = appointments.where((a) => a.id == appointmentId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Appointment not found')));
    }
    final appointment = matches.first;
    final doctor = ref.watch(authRepositoryProvider).getUserById(appointment.doctorId);
    final doctorProfile = ref.watch(doctorProfileProvider(appointment.doctorId));
    final clinics = ref.watch(mockDatabaseProvider).clinics;
    final matchingClinics = clinics.where((c) => c.id == appointment.clinicId);
    final clinic = matchingClinics.isNotEmpty
        ? matchingClinics.first
        : (clinics.isEmpty ? null : clinics.first);
    final canReschedule = appointment.status != AppointmentStatus.completed &&
        appointment.status != AppointmentStatus.cancelled;

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Appointment'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: StatusBadge(label: appointment.status.label, tone: _tone(appointment.status)),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                AvatarWidget(name: doctor?.fullName ?? 'Doctor', size: 52, color: colors.clinicianAccent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor?.fullName ?? 'Doctor', style: Theme.of(context).textTheme.titleMedium),
                      if (doctorProfile != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctorProfile.specialization,
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date & Time',
            value: '${DateFormatters.full(appointment.scheduledAt)} at ${DateFormatters.time(appointment.scheduledAt)}',
          ),
          _DetailRow(
            icon: Icons.medical_services_outlined,
            label: 'Type',
            value: '${appointment.appointmentType} · ${appointment.durationMinutes} minutes',
          ),
          if (appointment.reasonForVisit != null)
            _DetailRow(icon: Icons.notes_outlined, label: 'Reason', value: appointment.reasonForVisit!),
          if (clinic != null)
            _DetailRow(icon: Icons.location_on_outlined, label: 'Clinic', value: '${clinic.name}\n${clinic.address}'),
          if (clinic != null)
            _DetailRow(icon: Icons.phone_outlined, label: 'Clinic Phone', value: clinic.phone),
          if (canReschedule) ...[
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Reschedule',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReschedulePage(appointment: appointment)),
              ),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Cancel Appointment',
              onPressed: () async {
                await ref
                    .read(appointmentsRepositoryProvider)
                    .updateStatus(appointment.id, AppointmentStatus.cancelled);
                ref.read(appointmentsRevisionProvider.notifier).state++;
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, size: 16, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: colors.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13.5, color: colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
