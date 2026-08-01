import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import 'appointments_datasource.dart';

class MockAppointmentsDataSource implements AppointmentsDataSource {
  MockAppointmentsDataSource(this._db);

  final MockDatabase _db;

  @override
  List<Appointment> getForPatient(String patientId) {
    final list = _db.appointments.where((a) => a.patientId == patientId).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  List<Appointment> getForDoctor(String doctorId) {
    final list = _db.appointments.where((a) => a.doctorId == doctorId).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  Appointment? getNextUpcoming(String patientId) {
    final now = DateTime.now();
    final upcoming = _db.appointments
        .where((a) =>
            a.patientId == patientId &&
            a.scheduledAt.isAfter(now) &&
            a.status != AppointmentStatus.cancelled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  List<TimeSlot> getAvailableSlots({required String doctorId, required DateTime date}) {
    final booked = _db.appointments
        .where((a) =>
            a.doctorId == doctorId &&
            a.scheduledAt.year == date.year &&
            a.scheduledAt.month == date.month &&
            a.scheduledAt.day == date.day &&
            a.status != AppointmentStatus.cancelled)
        .map((a) => _SlotKey(hour: a.scheduledAt.hour, minute: a.scheduledAt.minute))
        .toSet();

    final slots = <TimeSlot>[];
    final isPastDay = DateTime(date.year, date.month, date.day)
        .isBefore(DateTime.now().subtract(const Duration(days: 1)));
    for (var hour = 9; hour < 17; hour++) {
      for (final minute in [0, 30]) {
        final dt = DateTime(date.year, date.month, date.day, hour, minute);
        final isBooked = booked.contains(_SlotKey(hour: hour, minute: minute));
        final isPast = dt.isBefore(DateTime.now());
        slots.add(TimeSlot(dateTime: dt, isBooked: isBooked, isDisabled: isBooked || isPast || isPastDay));
      }
    }
    return slots;
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
  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status) async {
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
