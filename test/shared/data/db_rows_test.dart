import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
import 'package:mypulse360/features/patient/domain/entities/wellness_goal.dart';
import 'package:mypulse360/shared/data/db_enums.dart';
import 'package:mypulse360/shared/data/db_rows.dart';

void main() {
  group('appointmentStatus mapping', () {
    test('round-trips every value', () {
      for (final s in AppointmentStatus.values) {
        expect(appointmentStatusFromDb(appointmentStatusToDb(s)), s);
      }
    });

    test('spells the multi-word label snake_case', () {
      expect(appointmentStatusToDb(AppointmentStatus.inProgress), 'in_progress');
    });

    test('throws on an unknown label rather than guessing', () {
      expect(() => appointmentStatusFromDb('no_show'), throwsArgumentError);
    });
  });

  group('appointmentFromRow', () {
    test('maps a row and parses the timestamp as UTC', () {
      final a = appointmentFromRow({
        'id': 'a1',
        'patient_id': 'p1',
        'doctor_id': 'd1',
        'clinic_id': 'c1',
        'scheduled_at': '2026-09-02T09:00:00+00:00',
        'duration_minutes': 30,
        'appointment_type': 'General checkup',
        'status': 'scheduled',
        'reason_for_visit': null,
        'room_label': null,
      });

      expect(a.id, 'a1');
      expect(a.status, AppointmentStatus.scheduled);
      expect(a.scheduledAt.isUtc, isTrue);
      expect(a.scheduledAt.hour, 9);
      expect(a.reasonForVisit, isNull);
    });
  });

  group('timeSlotFromRow', () {
    test('a booked slot is also disabled', () {
      final s = timeSlotFromRow({
        'slot_at': '2026-09-02T10:30:00+00:00',
        'is_booked': true,
        'is_doctor_on_leave': false,
        'is_past': false,
      });
      expect(s.isBooked, isTrue);
      expect(s.isDisabled, isTrue);
    });

    test('a free future slot is selectable', () {
      final s = timeSlotFromRow({
        'slot_at': '2026-09-02T11:00:00+00:00',
        'is_booked': false,
        'is_doctor_on_leave': false,
        'is_past': false,
      });
      expect(s.isDisabled, isFalse);
    });

    test('leave disables the slot even when nothing is booked', () {
      final s = timeSlotFromRow({
        'slot_at': '2026-09-02T11:00:00+00:00',
        'is_booked': false,
        'is_doctor_on_leave': true,
        'is_past': false,
      });
      expect(s.isDisabled, isTrue);
    });
  });

  group('patientProfileFromRow', () {
    test('maps a full row without transposing height/weight or dropping fields', () {
      final p = patientProfileFromRow({
        'id': 'p1',
        'date_of_birth': '1990-05-15',
        'gender': 'female',
        'blood_type': null,
        'height_cm': 170.5,
        'weight_kg': 65.2,
        'allergies': ['Penicillin', 'Peanuts'],
        'chronic_conditions': <String>[],
        'current_medications': <String>[],
        'assigned_doctor_id': 'd1',
        'insurance_provider': null,
        'emergency_contact_name': 'Jane Doe',
        'emergency_contact_phone': '555-1234',
        'preferred_clinic_id': 'c1',
        'preferred_language': 'en',
        'notify_appointments': false,
        'notify_prescriptions': true,
        'notify_health_tips': true,
      });

      expect(p.heightCm, 170.5);
      expect(p.weightKg, 65.2);
      expect(p.allergies, ['Penicillin', 'Peanuts']);
      expect(p.gender, 'female');
      expect(p.bloodType, isNull);
      expect(p.notifyAppointments, isFalse);
    });

    test('a null assigned_doctor_id maps to the empty-string sentinel', () {
      final p = patientProfileFromRow({
        'id': 'p1',
        'date_of_birth': null,
        'gender': null,
        'blood_type': null,
        'height_cm': 170.5,
        'weight_kg': 65.2,
        'allergies': <String>[],
        'chronic_conditions': <String>[],
        'current_medications': <String>[],
        'assigned_doctor_id': null,
        'insurance_provider': null,
        'emergency_contact_name': null,
        'emergency_contact_phone': null,
        'preferred_clinic_id': null,
        'preferred_language': null,
        'notify_appointments': true,
        'notify_prescriptions': true,
        'notify_health_tips': true,
      });

      expect(p.assignedDoctorId, '');
    });
  });

  group('wellnessGoalFromRow', () {
    test('resolves enum fields and keeps target/current values distinct', () {
      final g = wellnessGoalFromRow({
        'id': 'g1',
        'patient_id': 'p1',
        'type': 'hydration',
        'name': 'Drink water',
        'target_value': 8.0,
        'current_value': 3.0,
        'unit': 'glasses',
        'status': 'on_track',
        'target_date': '2026-12-31',
      });

      expect(g.type, WellnessGoalType.hydration);
      expect(g.status, GoalStatus.onTrack);
      expect(g.targetValue, 8.0);
      expect(g.currentValue, 3.0);
    });
  });

  group('wellnessGoalType mapping', () {
    test('spells the label snake_case', () {
      expect(wellnessGoalTypeToDb(WellnessGoalType.hydration), 'hydration');
    });

    test('throws on an unknown label rather than guessing', () {
      expect(() => wellnessGoalTypeFromDb('unknown'), throwsArgumentError);
    });
  });

  group('goalStatus mapping', () {
    test('spells the multi-word labels snake_case', () {
      expect(goalStatusToDb(GoalStatus.onTrack), 'on_track');
      expect(goalStatusToDb(GoalStatus.atRisk), 'at_risk');
    });

    test('throws on an unknown label rather than guessing', () {
      expect(() => goalStatusFromDb('unknown'), throwsArgumentError);
    });
  });
}
