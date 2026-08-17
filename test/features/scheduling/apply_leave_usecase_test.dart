import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/appointments/data/datasources/mock_appointments_datasource.dart';
import 'package:mypulse360/features/appointments/data/repositories/appointments_repository_impl.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
import 'package:mypulse360/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:mypulse360/features/scheduling/data/datasources/mock_scheduling_datasource.dart';
import 'package:mypulse360/features/scheduling/data/repositories/scheduling_repository_impl.dart';
import 'package:mypulse360/features/scheduling/domain/entities/leave_request.dart';
import 'package:mypulse360/features/scheduling/domain/usecases/apply_leave_usecase.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

/// The Apply Leave contract: taking leave has to update the booking system
/// in both directions — future slots on those days stop being offered, and
/// appointments already sitting inside the window are released.
void main() {
  late MockDatabase db;
  late AppointmentsRepository appointments;
  late ApplyLeaveUseCase applyLeave;

  // Far enough ahead that "in the past" slot rules never interfere.
  final leaveDay = DateTime.now().add(const Duration(days: 30));
  DateTime slotOn(DateTime day, int hour) => DateTime(day.year, day.month, day.day, hour);

  setUp(() {
    db = MockDatabase();
    appointments = AppointmentsRepositoryImpl(MockAppointmentsDataSource(db));
    applyLeave = ApplyLeaveUseCase(
      SchedulingRepositoryImpl(MockSchedulingDataSource(db)),
      appointments,
    );
  });

  test('leave closes the day for new bookings', () async {
    await applyLeave(
      staffId: MockIds.drAhmedUserId,
      startDate: leaveDay,
      endDate: leaveDay,
      reason: 'Vacation',
    );

    final slots = appointments.getAvailableSlots(doctorId: MockIds.drAhmedUserId, date: leaveDay);
    expect(slots, isNotEmpty);
    expect(slots.every((s) => s.isDisabled), isTrue);
    expect(slots.every((s) => s.isDoctorOnLeave), isTrue);
  });

  test('appointments already booked inside the window are cancelled', () async {
    final booked = await appointments.book(
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedUserId,
      scheduledAt: slotOn(leaveDay, 10),
      appointmentType: 'Follow-up',
    );

    final result = await applyLeave(
      staffId: MockIds.drAhmedUserId,
      startDate: leaveDay,
      endDate: leaveDay,
      reason: 'Vacation',
    );

    expect(result.cancelledAppointments.map((a) => a.id), [booked.id]);
    final after = appointments.getForDoctor(MockIds.drAhmedUserId).firstWhere((a) => a.id == booked.id);
    expect(after.status, AppointmentStatus.cancelled);
  });

  test('appointments outside the window and other doctors are left alone', () async {
    final outside = await appointments.book(
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedUserId,
      scheduledAt: slotOn(leaveDay.add(const Duration(days: 1)), 10),
      appointmentType: 'Follow-up',
    );
    final otherDoctor = await appointments.book(
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.fatimaUserId,
      scheduledAt: slotOn(leaveDay, 11),
      appointmentType: 'Follow-up',
    );

    final result = await applyLeave(
      staffId: MockIds.drAhmedUserId,
      startDate: leaveDay,
      endDate: leaveDay,
      reason: 'Vacation',
    );

    expect(result.cancelledAppointments, isEmpty);
    expect(
      appointments.getForDoctor(MockIds.drAhmedUserId).firstWhere((a) => a.id == outside.id).status,
      isNot(AppointmentStatus.cancelled),
    );
    expect(
      appointments.getForDoctor(MockIds.fatimaUserId).firstWhere((a) => a.id == otherDoctor.id).status,
      isNot(AppointmentStatus.cancelled),
    );
  });

  test('a multi-day leave clears every day it spans', () async {
    final lastDay = leaveDay.add(const Duration(days: 2));
    final middle = await appointments.book(
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedUserId,
      scheduledAt: slotOn(leaveDay.add(const Duration(days: 1)), 14),
      appointmentType: 'Follow-up',
    );

    final result = await applyLeave(
      staffId: MockIds.drAhmedUserId,
      startDate: leaveDay,
      endDate: lastDay,
      reason: 'Vacation',
    );

    expect(result.leave.status, LeaveStatus.approved);
    expect(result.cancelledAppointments.map((a) => a.id), contains(middle.id));
    for (final day in [leaveDay, leaveDay.add(const Duration(days: 1)), lastDay]) {
      final slots = appointments.getAvailableSlots(doctorId: MockIds.drAhmedUserId, date: day);
      expect(slots.every((s) => s.isDoctorOnLeave), isTrue, reason: 'day $day should read as on leave');
    }
  });

  test('appointmentsInRange previews the clash before the leave is taken', () async {
    await appointments.book(
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedUserId,
      scheduledAt: slotOn(leaveDay, 9),
      appointmentType: 'Follow-up',
    );

    final preview = applyLeave.appointmentsInRange(
      doctorId: MockIds.drAhmedUserId,
      startDate: leaveDay,
      endDate: leaveDay,
    );

    expect(preview, hasLength(1));
    expect(
      db.leaveRequests.where((l) => l.staffId == MockIds.drAhmedUserId),
      isEmpty,
      reason: 'previewing must not file anything',
    );
  });
}
