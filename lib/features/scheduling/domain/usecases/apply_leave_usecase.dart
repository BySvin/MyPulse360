import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointments_repository.dart';
import '../entities/leave_request.dart';
import '../repositories/scheduling_repository.dart';

/// Outcome of taking leave: the approved record, plus the appointments that
/// had to be cancelled because they sat inside the window.
class ApplyLeaveResult {
  const ApplyLeaveResult({
    required this.leave,
    required this.cancelledAppointments,
  });

  final LeaveRequest leave;
  final List<Appointment> cancelledAppointments;
}

/// Books a doctor's leave and keeps the booking side in sync with it.
///
/// Two things have to happen for "on leave" to be true from a patient's
/// point of view: future slots on those days must stop being offered (the
/// availability query already reads approved leave, so filing the record
/// is enough), and appointments *already* booked inside the window must be
/// released — otherwise a patient keeps a slot the doctor will not be
/// working. This use case does both in one step so the two can't drift.
class ApplyLeaveUseCase {
  ApplyLeaveUseCase(this._scheduling, this._appointments);

  final SchedulingRepository _scheduling;
  final AppointmentsRepository _appointments;

  Future<ApplyLeaveResult> call({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final affected = await appointmentsInRange(
      doctorId: staffId,
      startDate: startDate,
      endDate: endDate,
    );

    final leave = await _scheduling.requestLeave(
      staffId: staffId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      autoApprove: true,
    );

    for (final appointment in affected) {
      await _appointments.updateStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );
    }

    return ApplyLeaveResult(leave: leave, cancelledAppointments: affected);
  }

  /// Still-live appointments for [doctorId] between [startDate] and
  /// [endDate] inclusive. Also drives the warning shown before the leave is
  /// submitted, so the doctor sees the cost of the dates they picked.
  Future<List<Appointment>> appointmentsInRange({
    required String doctorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final appointments = await _appointments.getForDoctor(doctorId);
    return appointments
        .where(
          (a) =>
              a.status != AppointmentStatus.cancelled &&
              a.status != AppointmentStatus.completed &&
              !a.scheduledAt.isBefore(start) &&
              !a.scheduledAt.isAfter(end),
        )
        .toList();
  }
}
