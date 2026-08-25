import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/appointments/data/datasources/mock_appointments_datasource.dart';
import 'package:mypulse360/features/appointments/data/repositories/appointments_repository_impl.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
import 'package:mypulse360/features/appointments/domain/entities/time_slot.dart';
import 'package:mypulse360/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:mypulse360/features/scheduling/data/datasources/mock_scheduling_datasource.dart';
import 'package:mypulse360/features/scheduling/data/repositories/scheduling_repository_impl.dart';
import 'package:mypulse360/features/scheduling/domain/entities/leave_request.dart';
import 'package:mypulse360/features/scheduling/domain/usecases/apply_leave_usecase.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

/// Delegates everything to a real repository except [updateStatus], which
/// fails from the second call onward — simulating a network drop partway
/// through the per-appointment cancellation loop that
/// [ApplyLeaveUseCase.call] runs after the leave itself is already filed.
class _FlakyAfterFirstCancelRepository implements AppointmentsRepository {
  _FlakyAfterFirstCancelRepository(this._inner);

  final AppointmentsRepository _inner;
  int _updateStatusCalls = 0;

  @override
  Future<Appointment> updateStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    _updateStatusCalls++;
    if (_updateStatusCalls > 1) {
      throw Exception('network down');
    }
    return _inner.updateStatus(appointmentId, status);
  }

  @override
  Future<List<Appointment>> getForPatient(String patientId) =>
      _inner.getForPatient(patientId);

  @override
  Future<List<Appointment>> getForDoctor(String doctorId) =>
      _inner.getForDoctor(doctorId);

  @override
  Stream<Appointment?> watchNextUpcoming(String patientId) =>
      _inner.watchNextUpcoming(patientId);

  @override
  Stream<List<Appointment>> watchTodaysQueue(String doctorId) =>
      _inner.watchTodaysQueue(doctorId);

  @override
  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  }) => _inner.getAvailableSlots(doctorId: doctorId, date: date);

  @override
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>>
  getMonthAvailability({required String doctorId, required DateTime month}) =>
      _inner.getMonthAvailability(doctorId: doctorId, month: month);

  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) => _inner.book(
    patientId: patientId,
    doctorId: doctorId,
    scheduledAt: scheduledAt,
    appointmentType: appointmentType,
    reasonForVisit: reasonForVisit,
  );

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) =>
      _inner.reschedule(appointmentId, newTime);
}

/// The Apply Leave contract: taking leave has to update the booking system
/// in both directions — future slots on those days stop being offered, and
/// appointments already sitting inside the window are released.
void main() {
  late MockDatabase db;
  late AppointmentsRepository appointments;
  late ApplyLeaveUseCase applyLeave;

  // Far enough ahead that "in the past" slot rules never interfere.
  final leaveDay = DateTime.now().add(const Duration(days: 30));
  DateTime slotOn(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

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

    final slots = await appointments.getAvailableSlots(
      doctorId: MockIds.drAhmedUserId,
      date: leaveDay,
    );
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
    final after = (await appointments.getForDoctor(
      MockIds.drAhmedUserId,
    )).firstWhere((a) => a.id == booked.id);
    expect(after.status, AppointmentStatus.cancelled);
  });

  test(
    'appointments outside the window and other doctors are left alone',
    () async {
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
        (await appointments.getForDoctor(
          MockIds.drAhmedUserId,
        )).firstWhere((a) => a.id == outside.id).status,
        isNot(AppointmentStatus.cancelled),
      );
      expect(
        (await appointments.getForDoctor(
          MockIds.fatimaUserId,
        )).firstWhere((a) => a.id == otherDoctor.id).status,
        isNot(AppointmentStatus.cancelled),
      );
    },
  );

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
    for (final day in [
      leaveDay,
      leaveDay.add(const Duration(days: 1)),
      lastDay,
    ]) {
      final slots = await appointments.getAvailableSlots(
        doctorId: MockIds.drAhmedUserId,
        date: day,
      );
      expect(
        slots.every((s) => s.isDoctorOnLeave),
        isTrue,
        reason: 'day $day should read as on leave',
      );
    }
  });

  test(
    'appointmentsInRange previews the clash before the leave is taken',
    () async {
      await appointments.book(
        patientId: MockIds.sarahPatientId,
        doctorId: MockIds.drAhmedUserId,
        scheduledAt: slotOn(leaveDay, 9),
        appointmentType: 'Follow-up',
      );

      final preview = await applyLeave.appointmentsInRange(
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
    },
  );

  test(
    'a cancellation failure partway through reports the partial success '
    'instead of losing it in a generic error',
    () async {
      final first = await appointments.book(
        patientId: MockIds.sarahPatientId,
        doctorId: MockIds.drAhmedUserId,
        scheduledAt: slotOn(leaveDay, 9),
        appointmentType: 'Follow-up',
      );
      final second = await appointments.book(
        patientId: MockIds.sarahPatientId,
        doctorId: MockIds.drAhmedUserId,
        scheduledAt: slotOn(leaveDay, 11),
        appointmentType: 'Follow-up',
      );

      final flaky = _FlakyAfterFirstCancelRepository(appointments);
      final flakyApplyLeave = ApplyLeaveUseCase(
        SchedulingRepositoryImpl(MockSchedulingDataSource(db)),
        flaky,
      );

      LeaveAppointmentCancellationException? caught;
      try {
        await flakyApplyLeave(
          staffId: MockIds.drAhmedUserId,
          startDate: leaveDay,
          endDate: leaveDay,
          reason: 'Vacation',
        );
        fail('expected LeaveAppointmentCancellationException');
      } on LeaveAppointmentCancellationException catch (e) {
        caught = e;
      }

      // The leave itself is on record — it must not be rolled back.
      expect(
        db.leaveRequests.where((l) => l.staffId == MockIds.drAhmedUserId),
        isNotEmpty,
        reason: 'the leave was filed and must stay filed',
      );

      expect(caught.cancelledAppointments.map((a) => a.id), [first.id]);
      expect(caught.uncancelledAppointments.map((a) => a.id), [second.id]);
      expect(caught.toString(), contains('filed'));
      expect(caught.toString(), contains('could not be cancelled'));
    },
  );
}
