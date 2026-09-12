import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.8,
          colors: [
            colors.patientAccent,
            colors.patientAccent.withValues(alpha: 0.4),
            const Color(0xFF101015),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: colors.patientAccent.withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
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
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              StatusBadge(
                label: appointment.status.label,
                tone: confirmed ? StatusTone.success : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(doctorName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${DateFormatters.full(appointment.scheduledAt)} at ${DateFormatters.time(appointment.scheduledAt)}',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.medical_services_outlined, size: 14, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${appointment.appointmentType} · ${appointment.durationMinutes} minutes',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: onViewDetails,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(color: colors.patientAccent, fontSize: 13, fontWeight: FontWeight.w700),
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
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
