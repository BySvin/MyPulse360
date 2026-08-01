import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/domain/entities/appointment.dart';

class NextAppointmentBanner extends StatelessWidget {
  const NextAppointmentBanner({
    super.key,
    required this.appointment,
    required this.doctorName,
    this.onViewDetails,
    this.onReschedule,
  });

  final Appointment appointment;
  final String doctorName;
  final VoidCallback? onViewDetails;
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final confirmed = appointment.status == AppointmentStatus.confirmed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.patientAccent.withValues(alpha: 0.06),
        border: Border.all(color: colors.patientAccent),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEXT APPOINTMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.patientAccentText,
                ),
              ),
              StatusBadge(
                label: appointment.status.label,
                tone: confirmed ? StatusTone.success : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(doctorName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: colors.textSecondary),
              const SizedBox(width: 7),
              Text(
                '${DateFormatters.full(appointment.scheduledAt)} at ${DateFormatters.time(appointment.scheduledAt)}',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.medical_services_outlined, size: 14, color: colors.textSecondary),
              const SizedBox(width: 7),
              Text(
                '${appointment.appointmentType} · ${appointment.durationMinutes} minutes',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onViewDetails,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.patientAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onReschedule,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Reschedule',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
