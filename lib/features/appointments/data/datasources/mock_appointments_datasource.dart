import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../../scheduling/domain/entities/leave_request.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import 'appointments_datasource.dart';

class MockAppointmentsDataSource implements AppointmentsDataSource {
  MockAppointmentsDataSource(this._db);

  final MockDatabase _db;

  @override
  Future<List<Appointment>> getForPatient(String patientId) async {
    final list =
        _db.appointments.where((a) => a.patientId == patientId).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  Future<List<Appointment>> getForDoctor(String doctorId) async {
    final list = _db.appointments.where((a) => a.doctorId == doctorId).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  Appointment? _nextUpcoming(String patientId) {
    final now = DateTime.now();
    final upcoming =
        _db.appointments
            .where(
              (a) =>
                  a.patientId == patientId &&
                  a.scheduledAt.isAfter(now) &&
                  a.status != AppointmentStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Stream<Appointment?> watchNextUpcoming(String patientId) =>
      Stream.value(_nextUpcoming(patientId));

  List<Appointment> _todaysQueue(String doctorId) {
    final now = DateTime.now();
    final list =
        _db.appointments
            .where(
              (a) =>
                  a.doctorId == doctorId &&
                  a.scheduledAt.year == now.year &&
                  a.scheduledAt.month == now.month &&
                  a.scheduledAt.day == now.day &&
                  a.status != AppointmentStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  Stream<List<Appointment>> watchTodaysQueue(String doctorId) =>
      Stream.value(_todaysQueue(doctorId));

  List<TimeSlot> getAvailableSlotsSync({
    required String doctorId,
    required DateTime date,
  }) {
    final onLeave = _db.leaveRequests.any(
      (l) =>
          l.staffId == doctorId &&
          l.status == LeaveStatus.approved &&
          l.coversDate(date),
    );

    final booked = _db.appointments
        .where(
          (a) =>
              a.doctorId == doctorId &&
              a.scheduledAt.year == date.year &&
              a.scheduledAt.month == date.month &&
              a.scheduledAt.day == date.day &&
              a.status != AppointmentStatus.cancelled,
        )
        .map(
          (a) =>
              _SlotKey(hour: a.scheduledAt.hour, minute: a.scheduledAt.minute),
        )
        .toSet();

    final slots = <TimeSlot>[];
    final isPastDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime.now().subtract(const Duration(days: 1)));
    for (var hour = 9; hour < 17; hour++) {
      for (final minute in [0, 30]) {
        final dt = DateTime(date.year, date.month, date.day, hour, minute);
        final isBooked = booked.contains(_SlotKey(hour: hour, minute: minute));
        final isPast = dt.isBefore(DateTime.now());
        slots.add(
          TimeSlot(
            dateTime: dt,
            isBooked: isBooked,
            isDisabled: onLeave || isBooked || isPast || isPastDay,
            isDoctorOnLeave: onLeave,
          ),
        );
      }
    }
    return slots;
  }

  @override
  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  }) async => getAvailableSlotsSync(doctorId: doctorId, date: date);

  @override
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>>
  getMonthAvailability({
    required String doctorId,
    required DateTime month,
  }) async {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    return [
      for (var i = 0; i < days; i++)
        () {
          final day = DateTime(first.year, first.month, i + 1);
          final slots = getAvailableSlotsSync(doctorId: doctorId, date: day);
          return (
            day: day,
            openSlots: slots.where((s) => !s.isDisabled).length,
            isOnLeave: slots.any((s) => s.isDoctorOnLeave),
          );
        }(),
    ];
  }

  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) async {
    await simulateLatency();
    final appt = Appointment(
      id: generateId(),
      patientId: patientId,
      doctorId: doctorId,
      clinicId: _db.userById(doctorId)?.clinicId ?? '',
      scheduledAt: scheduledAt,
      durationMinutes: 30,
      appointmentType: appointmentType,
      status: AppointmentStatus.confirmed,
      reasonForVisit: reasonForVisit,
    );
    _db.appointments.add(appt);
    return appt;
  }

  @override
  Future<Appointment> updateStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    await simulateLatency();
    final i = _db.appointments.indexWhere((a) => a.id == appointmentId);
    if (i == -1) throw StateError('Appointment not found');
    final updated = _db.appointments[i].copyWith(status: status);
    _db.appointments[i] = updated;
    return updated;
  }

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) async {
    await simulateLatency();
    final i = _db.appointments.indexWhere((a) => a.id == appointmentId);
    if (i == -1) throw StateError('Appointment not found');
    final updated = _db.appointments[i].copyWith(
      status: AppointmentStatus.rescheduled,
      scheduledAt: newTime,
    );
    _db.appointments[i] = updated;
    return updated;
  }
}

class _SlotKey {
  const _SlotKey({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is _SlotKey && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
