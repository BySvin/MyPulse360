import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/appointment.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, required this.doctorName, this.onTap});

  final Appointment appointment;
  final String doctorName;
  final VoidCallback? onTap;

  StatusTone get _tone => switch (appointment.status) {
        AppointmentStatus.confirmed => StatusTone.success,
        AppointmentStatus.completed => StatusTone.info,
        AppointmentStatus.cancelled => StatusTone.danger,
        AppointmentStatus.scheduled => StatusTone.neutral,
        AppointmentStatus.inProgress => StatusTone.warning,
        AppointmentStatus.rescheduled => StatusTone.warning,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AvatarWidget(name: doctorName, color: colors.clinicianAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctorName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${DateFormatters.short(appointment.scheduledAt)} · ${DateFormatters.time(appointment.scheduledAt)}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(appointment.appointmentType, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
          StatusBadge(label: appointment.status.label, tone: _tone),
        ],
      ),
    );
  }
}
