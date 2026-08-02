import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../appointments/domain/entities/appointment.dart';

/// Waiting/completed status for a queued appointment — shared by the
/// doctor dashboard's queue rows and the patient's own Queue Status page,
/// so the "30+ min" rule lives in exactly one place.
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
