import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_enums.dart';
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
          .order('scheduled_at');
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
          // `month_availability.day` is a bare Postgres `date` (no time, no
          // zone). `DateTime.parse` on that alone yields a local-time
          // DateTime; appending T00:00:00Z pins it to UTC midnight instead,
          // matching the invariant the rest of this file keeps via
          // db_rows.dart's `_utc()`.
          day: DateTime.parse('${m['day'] as String}T00:00:00Z'),
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
    return _client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((rows) {
          final now = DateTime.now().toUtc();
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
          // "Today" is the clinic's day, not UTC's. Bucketing on the UTC
          // calendar day put a 9am Kuala Lumpur appointment (01:00Z) on the
          // right day only by luck of the offset, and would drop or add
          // appointments either side of midnight local. Both sides of the
          // comparison are converted, so the whole test is in one zone.
          final today = DateTime.now();
          return rows
              .map((r) => appointmentFromRow(Map<String, dynamic>.from(r)))
              .where((a) {
                final at = a.scheduledAt.toLocal();
                return a.status != AppointmentStatus.cancelled &&
                    at.year == today.year &&
                    at.month == today.month &&
                    at.day == today.day;
              })
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
  }) async {
    try {
      // patientId is ignored deliberately: book_appointment derives the patient
      // from auth.uid() so a client cannot book on someone else's behalf.
      final row = await _client.rpc('book_appointment', params: {
        'p_doctor': doctorId,
        'p_at': scheduledAt.toUtc().toIso8601String(),
        'p_type': appointmentType,
        'p_reason': reasonForVisit,
      });
      return appointmentFromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status) async {
    try {
      // set_appointment_status's second parameter is the appointment_status
      // enum, not text. appointmentStatusToDb(status) is a Dart String;
      // verified live against the project that PostgREST casts the JSON
      // string to the enum correctly.
      final row = await _client.rpc('set_appointment_status', params: {
        'p_appointment': appointmentId,
        'p_status': appointmentStatusToDb(status),
      });
      return appointmentFromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) async {
    try {
      final row = await _client.rpc('reschedule_appointment', params: {
        'p_appointment': appointmentId,
        'p_new_at': newTime.toUtc().toIso8601String(),
      });
      return appointmentFromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
}
