import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_enums.dart';
import '../../../../shared/data/db_failure.dart';
import '../../../../shared/data/db_rows.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import 'patient_datasource.dart';

class SupabasePatientDataSource implements PatientDataSource {
  SupabasePatientDataSource(this._client);

  final SupabaseClient _client;

  static const _profileCols =
      'id, date_of_birth, gender, blood_type, height_cm, weight_kg, allergies, '
      'chronic_conditions, current_medications, assigned_doctor_id, '
      'insurance_provider, emergency_contact_name, emergency_contact_phone, '
      'preferred_clinic_id, preferred_language, notify_appointments, '
      'notify_prescriptions, notify_health_tips';

  static const _goalCols =
      'id, patient_id, type, name, target_value, current_value, unit, status, target_date';

  @override
  Future<PatientProfile?> getProfile(String patientId) async {
    try {
      final row = await _client
          .from('patient_profiles')
          .select(_profileCols)
          .eq('id', patientId)
          .maybeSingle();
      return row == null ? null : patientProfileFromRow(row);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<List<WellnessGoal>> getWellnessGoals(String patientId) async {
    try {
      final rows = await _client
          .from('wellness_goals')
          .select(_goalCols)
          .eq('patient_id', patientId)
          .order('target_date');
      return rows.map(wellnessGoalFromRow).toList();
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// `register_patient()` (`supabase/migrations/0018_register_patient.sql`)
  /// already inserts the `patient_profiles` row and assigns the default
  /// doctor, in one transaction, at sign-up. This method has no Supabase
  /// call site as a result.
  ///
  /// It is deliberately not "implemented" as insert-then-`assign_default_doctor()`
  /// either: `assigned_doctor_id` is not writable by `authenticated` (grant
  /// check on `patient_profiles`), so an insert can only ever leave it null,
  /// and a follow-up RPC call would be a second round trip outside
  /// `register_patient`'s transaction — reintroducing exactly the
  /// half-created-account risk that function's docstring says
  /// `SECURITY DEFINER` exists to avoid. Throwing here instead of silently
  /// duplicating that logic keeps there being exactly one place a patient
  /// profile gets created.
  @override
  Future<PatientProfile> createInitialProfile({
    required String patientId,
    required String assignedDoctorId,
  }) async {
    throw const DbFailure(
      'Patient profiles are created at sign-up. If you are seeing this, '
      'something tried to create one outside register_patient().',
    );
  }

  @override
  Future<void> seedStarterGoals({
    required String patientId,
    required List<WellnessGoalType> selectedGoals,
  }) async {
    if (selectedGoals.isEmpty) return;
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    final targetDate = _dateOnly(endOfWeek);
    final rows = selectedGoals.map((type) {
      final (target, unit) = switch (type) {
        WellnessGoalType.exercise => (5.0, 'sessions'),
        WellnessGoalType.hydration => (8.0, 'glasses'),
        WellnessGoalType.sleep => (8.0, 'hours avg'),
        WellnessGoalType.diet => (3.0, 'meals logged'),
        WellnessGoalType.custom => (1.0, 'times'),
      };
      return {
        'patient_id': patientId,
        'type': wellnessGoalTypeToDb(type),
        'name': type.label,
        'target_value': target,
        'current_value': 0,
        'unit': unit,
        'status': goalStatusToDb(GoalStatus.onTrack),
        'target_date': targetDate,
      };
    }).toList();
    try {
      await _client.from('wellness_goals').insert(rows);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<PatientProfile> updateProfile(
    String patientId, {
    double? heightCm,
    double? weightKg,
    List<String>? allergies,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    List<String>? chronicConditions,
    String? insuranceProvider,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? preferredClinicId,
    String? preferredLanguage,
    bool? notifyAppointments,
    bool? notifyPrescriptions,
    bool? notifyHealthTips,
  }) async {
    // Built from non-null arguments only, so an omitted field is left alone
    // rather than overwritten with NULL. `id` and `assigned_doctor_id` are
    // never included: neither is writable by `authenticated` (finding B),
    // and `assigned_doctor_id` in particular has its own SECURITY DEFINER
    // write path (`assign_default_doctor`).
    final updates = <String, dynamic>{
      'height_cm': ?heightCm,
      'weight_kg': ?weightKg,
      'allergies': ?allergies,
      if (dateOfBirth != null) 'date_of_birth': _dateOnly(dateOfBirth),
      'gender': ?gender,
      'blood_type': ?bloodType,
      'chronic_conditions': ?chronicConditions,
      'insurance_provider': ?insuranceProvider,
      'emergency_contact_name': ?emergencyContactName,
      'emergency_contact_phone': ?emergencyContactPhone,
      'preferred_clinic_id': ?preferredClinicId,
      'preferred_language': ?preferredLanguage,
      'notify_appointments': ?notifyAppointments,
      'notify_prescriptions': ?notifyPrescriptions,
      'notify_health_tips': ?notifyHealthTips,
    };
    try {
      if (updates.isEmpty) {
        // Nothing to write — an empty `.update({})` is either rejected or a
        // no-op depending on the driver; reading back the current row is the
        // unambiguous answer to "what does the profile look like now".
        final row = await _client
            .from('patient_profiles')
            .select(_profileCols)
            .eq('id', patientId)
            .single();
        return patientProfileFromRow(row);
      }
      final row = await _client
          .from('patient_profiles')
          .update(updates)
          .eq('id', patientId)
          .select(_profileCols)
          .single();
      return patientProfileFromRow(row);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  /// No `DELETE` policy exists on `patient_profiles` (`docs/PROJECT-STATUS.md`
  /// limitation 3 — eight foreign keys reference `profiles` with `NO ACTION`,
  /// and `is_active` is the intended soft-delete). A table-level `DELETE`
  /// grant to `authenticated` does exist, but with no policy RLS denies every
  /// row, so a `.delete()` call here would not even raise an error — it would
  /// silently affect zero rows and look like success. Refusing up front,
  /// before touching the network, is the only way to avoid that trap.
  @override
  Future<void> deleteAccount(String patientId) async {
    throw const DbFailure(
      "Account deletion isn't available yet — contact the clinic.",
    );
  }

  /// Postgres `date` wants a bare calendar day. Sending a full timestamp
  /// makes the server reinterpret it in its own zone and risks landing on
  /// the wrong day near midnight.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
