import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
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
}
