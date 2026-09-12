import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_failure.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/entities/staff_notification.dart';
import '../../domain/entities/staff_unavailability.dart';
import 'scheduling_datasource.dart';

/// Leave / attendance against the real backend. The product requirement is
/// that a doctor's approved leave is immediately true from a patient's point
/// of view: the availability queries (`available_slots`, `month_availability`)
/// already read `leave_requests.status = 'approved'` server-side, so filing and
/// deciding the record here is what closes those days. Cancellation goes
/// through `cancel_leave()` (`0026_cancel_leave.sql`) because `leave_requests`
/// has no client-side DELETE.
class SupabaseSchedulingDataSource implements SchedulingDataSource {
  SupabaseSchedulingDataSource(this._client);

  final SupabaseClient _client;

  DateTime _utc(Object? v) => DateTime.parse(v! as String).toUtc();

  DateTime _date(Object? v) => DateTime.parse(v! as String);

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// `apply_leave` / `decide_leave` / `clock_in` return a single composite row,
  /// surfaced by PostgREST as a JSON object (surprisingly sometimes a list).
  Map<String, dynamic> _asMap(Object? row) =>
      Map<String, dynamic>.from(row is List ? row.first as Map : row as Map);

  LeaveRequest _leaveFromRow(Map<String, dynamic> r) => LeaveRequest(
        id: r['id'] as String,
        staffId: r['staff_id'] as String,
        startDate: _date(r['start_date']),
        endDate: _date(r['end_date']),
        reason: r['reason'] as String,
        status: _leaveStatusFromDb(r['status'] as String),
        requestedAt: _utc(r['requested_at']),
        decidedBy: r['decided_by'] as String?,
        decidedAt: r['decided_at'] == null ? null : _utc(r['decided_at']),
      );

  String _leaveStatusToDb(LeaveStatus s) => switch (s) {
        LeaveStatus.pending => 'pending',
        LeaveStatus.approved => 'approved',
        LeaveStatus.denied => 'denied',
      };

  LeaveStatus _leaveStatusFromDb(String label) => switch (label) {
        'pending' => LeaveStatus.pending,
        'approved' => LeaveStatus.approved,
        'denied' => LeaveStatus.denied,
        _ => throw ArgumentError.value(label, 'status', 'Unknown leave_status'),
      };

  AttendanceRecord _attendanceFromRow(Map<String, dynamic> r) => AttendanceRecord(
        id: r['id'] as String,
        staffId: r['staff_id'] as String,
        clockInAt: _utc(r['clock_in_at']),
        clockOutAt: r['clock_out_at'] == null ? null : _utc(r['clock_out_at']),
      );

  StaffNotification _notificationFromRow(Map<String, dynamic> r) =>
      StaffNotification(
        id: r['id'] as String,
        staffId: r['staff_id'] as String,
        message: r['message'] as String,
        sentAt: _utc(r['sent_at']),
      );

  StaffUnavailability _unavailabilityFromRow(Map<String, dynamic> r) =>
      StaffUnavailability(
        id: r['id'] as String,
        staffId: r['staff_id'] as String,
        date: _date(r['date']),
        reason: r['reason'] as String?,
      );

  // Shifts are no longer tracked — these are pure stubs that existed for the
  // removed scheduling module and are forward-compatible with a re-add.
  @override
  bool hasConflict(String staffId, DateTime start, DateTime end) => false;

  @override
  double weeklyScheduledHours(String staffId, DateTime anyDayInWeek) => 0;

  @override
  double weeklyOvertimeHours(
    String staffId,
    DateTime anyDayInWeek, {
    double weeklyThreshold = 40,
  }) =>
      0;

  /// No UI consumes this today. A live candidate read would need to resolve
  /// weekly hours server-side; returning the empty list is honest about that
  /// rather than returning staff who may be unavailable.
  @override
  List<AppUser> suggestStaff({
    required UserRole role,
    required String clinicId,
    required DateTime start,
    required DateTime end,
  }) =>
      const [];

  @override
  Future<List<LeaveRequest>> getLeaveRequests(String clinicId) async {
    try {
      // RLS already scopes profiles to own-row (anyone) or same-clinic staff
      // (doctor/pharmacist), so this intersection is the clinic's staff. A
      // patient asking for clinic-wide leave gets only their own rows back.
      final staffRows = await _client
          .from('profiles')
          .select('id')
          .eq('clinic_id', clinicId);
      final staffIds = staffRows.map((r) => r['id'] as String).toList();
      if (staffIds.isEmpty) return [];
      final rows = await _client
          .from('leave_requests')
          .select('*')
          .inFilter('staff_id', staffIds)
          .order('requested_at', ascending: false);
      return rows.map(_leaveFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForStaff(String staffId) async {
    try {
      final rows = await _client
          .from('leave_requests')
          .select('*')
          .eq('staff_id', staffId)
          .order('requested_at', ascending: false);
      return rows.map(_leaveFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<LeaveRequest> requestLeave({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    bool autoApprove = false,
  }) async {
    try {
      final filed = await _client.rpc('apply_leave', params: {
        'p_start': _dateOnly(startDate),
        'p_end': _dateOnly(endDate),
        'p_reason': reason,
      });
      final row = _asMap(filed);
      if (!autoApprove) return _leaveFromRow(row);
      // The doctor is their own approver (no-one above them to ratify), and
      // decide_leave also cancels colliding appointments + notifies in the
      // same transaction — matching the ApplyLeaveUseCase contract.
      final decided = await _client.rpc('decide_leave', params: {
        'p_request': row['id'],
        'p_status': 'approved',
      });
      return _leaveFromRow(_asMap(decided));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> decideLeave(
    String leaveId, {
    required LeaveStatus status,
    required String decidedBy,
  }) async {
    try {
      await _client.rpc('decide_leave', params: {
        'p_request': leaveId,
        'p_status': _leaveStatusToDb(status),
      });
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> cancelLeave(String leaveId) async {
    try {
      await _client.rpc('cancel_leave', params: {'p_request': leaveId});
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<StaffUnavailability>> getUnavailability(String staffId) async {
    try {
      final rows = await _client
          .from('staff_unavailability')
          .select('*')
          .eq('staff_id', staffId)
          .order('date');
      return rows.map(_unavailabilityFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> markUnavailable({
    required String staffId,
    required DateTime date,
    String? reason,
  }) async {
    try {
      await _client.from('staff_unavailability').insert({
        'staff_id': staffId,
        'date': _dateOnly(date),
        'reason': reason,
      });
    } catch (e) {
      // `unique (staff_id, date)` — marking an already-marked day is a no-op.
      if (e is PostgrestException && e.code == '23505') return;
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> clearUnavailability(String id) async {
    try {
      await _client.from('staff_unavailability').delete().eq('id', id);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<AttendanceRecord?> getOpenAttendance(String staffId) async {
    try {
      final rows = await _client
          .from('attendance_records')
          .select('*')
          .eq('staff_id', staffId)
          .isFilter('clock_out_at', null)
          .limit(1);
      return rows.isEmpty ? null : _attendanceFromRow(rows.first);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForStaff(String staffId) async {
    try {
      final rows = await _client
          .from('attendance_records')
          .select('*')
          .eq('staff_id', staffId)
          .order('clock_in_at', ascending: false);
      return rows.map(_attendanceFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<AttendanceRecord> clockIn({required String staffId}) async {
    try {
      final row = await _client.rpc('clock_in');
      return _attendanceFromRow(_asMap(row));
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<void> clockOut(String attendanceId) async {
    try {
      await _client.rpc('clock_out');
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<StaffNotification>> getNotifications(String staffId) async {
    try {
      final rows = await _client
          .from('staff_notifications')
          .select('*')
          .eq('staff_id', staffId)
          .order('sent_at', ascending: false);
      return rows.map(_notificationFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }
}