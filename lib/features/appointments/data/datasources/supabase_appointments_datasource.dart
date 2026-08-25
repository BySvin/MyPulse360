import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_failure.dart';
import '../../../../shared/data/db_rows.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import 'appointments_datasource.dart';

// `appointment.dart` carries both Appointment and AppointmentStatus; the
// streams below filter on the latter.

class SupabaseAppointmentsDataSource implements AppointmentsDataSource {
  SupabaseAppointmentsDataSource(this._client);

  final SupabaseClient _client;

  static const _cols =
      'id, patient_id, doctor_id, clinic_id, scheduled_at, duration_minutes, '
      'appointment_type, status, reason_for_visit, room_label';

  @override
  Future<List<Appointment>> getForPatient(String patientId) async {
    try {
      final rows = await _client
          .from('appointments')
          .select(_cols)
          .eq('patient_id', patientId)
          .order('scheduled_at', ascending: false);
      return rows.map(appointmentFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<Appointment>> getForDoctor(String doctorId) async {
    try {
      final rows = await _client
          .from('appointments')
          .select(_cols)
          .eq('doctor_id', doctorId)
          .order('scheduled_at');
      return rows.map(appointmentFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<TimeSlot>> getAvailableSlots({
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final rows = await _client.rpc('available_slots', params: {
        'p_doctor': doctorId,
        'p_date': _dateOnly(date),
      });
      return (rows as List).map((r) => timeSlotFromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<({DateTime day, int openSlots, bool isOnLeave})>> getMonthAvailability({
    required String doctorId,
    required DateTime month,
  }) async {
    try {
      final rows = await _client.rpc('month_availability', params: {
        'p_doctor': doctorId,
        'p_month': _dateOnly(DateTime(month.year, month.month, 1)),
      });
      return (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        return (
          day: DateTime.parse(m['day'] as String),
          openSlots: m['open_slots'] as int,
          isOnLeave: m['is_on_leave'] as bool,
        );
      }).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// Postgres `date` wants a bare calendar day. Sending a full timestamp makes
  /// the server reinterpret it in its own zone and silently answer for the
  /// wrong day near midnight.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Realtime on `appointments`, filtered to this patient. `stream` needs the
  /// table's primary key to diff rows.
  @override
  Stream<Appointment?> watchNextUpcoming(String patientId) {
    final now = DateTime.now().toUtc();
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((rows) {
          final upcoming = rows
              .map((r) => appointmentFromRow(Map<String, dynamic>.from(r)))
              .where((a) =>
                  a.status != AppointmentStatus.cancelled &&
                  a.scheduledAt.isAfter(now))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return upcoming.isEmpty ? null : upcoming.first;
        })
        .handleError((Object e) => throw mapPostgrestError(e));
  }

  @override
  Stream<List<Appointment>> watchTodaysQueue(String doctorId) {
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .map((rows) {
          final today = DateTime.now().toUtc();
          return rows
              .map((r) => appointmentFromRow(Map<String, dynamic>.from(r)))
              .where((a) =>
                  a.status != AppointmentStatus.cancelled &&
                  a.scheduledAt.year == today.year &&
                  a.scheduledAt.month == today.month &&
                  a.scheduledAt.day == today.day)
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        })
        .handleError((Object e) => throw mapPostgrestError(e));
  }

  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) async =>
      throw UnimplementedError('Booking lands in Task 6');

  @override
  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status) async =>
      throw UnimplementedError('Status changes land in Task 6');

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) async =>
      throw UnimplementedError('Rescheduling lands in Task 6');
}
