import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/domain/entities/appointment.dart';

/// Waiting/completed status shared by [PatientQueueTile] (mobile card) and
/// the desktop queue table, so the "30+ min" rule lives in exactly one place.
class QueueStatus {
  const QueueStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  factory QueueStatus.forAppointment(Appointment appointment) {
    final isLate = appointment.status != AppointmentStatus.completed &&
        DateTime.now().difference(appointment.scheduledAt).inMinutes > 30;
    if (appointment.status == AppointmentStatus.completed) {
      return const QueueStatus('Completed', StatusTone.info);
    }
    if (isLate) return const QueueStatus('Waiting 30+ min', StatusTone.warning);
    return QueueStatus(appointment.status.label, StatusTone.success);
  }
}

class PatientQueueTile extends StatelessWidget {
  const PatientQueueTile({
    super.key,
    required this.appointment,
    required this.patientName,
    this.onTap,
  });

  final Appointment appointment;
  final String patientName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = QueueStatus.forAppointment(appointment);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AvatarWidget(name: patientName, color: colors.clinicianAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${DateFormatters.time(appointment.scheduledAt)} · ${appointment.appointmentType}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                if (appointment.reasonForVisit != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    appointment.reasonForVisit!,
                    style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          StatusBadge(label: status.label, tone: status.tone),
        ],
      ),
    );
  }
}
