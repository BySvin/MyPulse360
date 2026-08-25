import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/appointments/domain/entities/time_slot.dart';
import '../../features/patient/domain/entities/patient_profile.dart';
import '../../features/patient/domain/entities/wellness_goal.dart';
import 'db_enums.dart';

/// Postgres row → domain entity. Field names appear here and nowhere else, so
/// a column rename fails in one file rather than at three call sites.

DateTime _utc(Object? v) => DateTime.parse(v! as String).toUtc();

Appointment appointmentFromRow(Map<String, dynamic> r) => Appointment(
      id: r['id'] as String,
      patientId: r['patient_id'] as String,
      doctorId: r['doctor_id'] as String,
      clinicId: r['clinic_id'] as String,
      scheduledAt: _utc(r['scheduled_at']),
      durationMinutes: r['duration_minutes'] as int,
      appointmentType: r['appointment_type'] as String,
      status: appointmentStatusFromDb(r['status'] as String),
      reasonForVisit: r['reason_for_visit'] as String?,
      roomLabel: r['room_label'] as String?,
    );

/// `available_slots` already computes booked / on-leave / past server-side.
/// `isDisabled` is the union of those three: the UI only needs to know whether
/// the slot can be tapped, and deriving it here keeps that rule in one place.
/// `isSelected` is deliberately not set: it is UI state the booking page owns
/// via `copyWith`, not something the database knows. Confirmed `TimeSlot`'s
/// constructor defaults `isSelected` to `false`.
TimeSlot timeSlotFromRow(Map<String, dynamic> r) {
  final booked = r['is_booked'] as bool;
  final onLeave = r['is_doctor_on_leave'] as bool;
  final past = r['is_past'] as bool;
  return TimeSlot(
    dateTime: _utc(r['slot_at']),
    isBooked: booked,
    isDoctorOnLeave: onLeave,
    isDisabled: booked || onLeave || past,
  );
}

List<String> _textArray(Object? v) =>
    (v as List?)?.map((e) => e as String).toList() ?? const [];

/// `assignedDoctorId` on `PatientProfile` is non-nullable, but the
/// `assigned_doctor_id` column is nullable (a patient may not yet be
/// assigned a doctor). `?? ''` is a placeholder to satisfy that mismatch —
/// flagged in the task report rather than silently accepted.
PatientProfile patientProfileFromRow(Map<String, dynamic> r) => PatientProfile(
      id: r['id'] as String,
      dateOfBirth: r['date_of_birth'] == null ? null : DateTime.parse(r['date_of_birth'] as String),
      gender: r['gender'] as String?,
      bloodType: r['blood_type'] as String?,
      heightCm: (r['height_cm'] as num).toDouble(),
      weightKg: (r['weight_kg'] as num).toDouble(),
      allergies: _textArray(r['allergies']),
      chronicConditions: _textArray(r['chronic_conditions']),
      currentMedications: _textArray(r['current_medications']),
      assignedDoctorId: r['assigned_doctor_id'] as String? ?? '',
      insuranceProvider: r['insurance_provider'] as String?,
      emergencyContactName: r['emergency_contact_name'] as String?,
      emergencyContactPhone: r['emergency_contact_phone'] as String?,
      preferredClinicId: r['preferred_clinic_id'] as String?,
      preferredLanguage: r['preferred_language'] as String?,
      notifyAppointments: r['notify_appointments'] as bool,
      notifyPrescriptions: r['notify_prescriptions'] as bool,
      notifyHealthTips: r['notify_health_tips'] as bool,
    );

WellnessGoal wellnessGoalFromRow(Map<String, dynamic> r) => WellnessGoal(
      id: r['id'] as String,
      patientId: r['patient_id'] as String,
      type: wellnessGoalTypeFromDb(r['type'] as String),
      name: r['name'] as String,
      targetValue: (r['target_value'] as num).toDouble(),
      currentValue: (r['current_value'] as num).toDouble(),
      unit: r['unit'] as String,
      status: goalStatusFromDb(r['status'] as String),
      targetDate: DateTime.parse(r['target_date'] as String),
    );
