import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/prescriptions/domain/scanned_prescription_parser.dart';

void main() {
  test('parses a fully populated payload', () {
    final payload = parseScannedPrescriptionPayload('''
    {
      "prescriberName": "Dr. Jane Smith",
      "issuedDate": "2026-08-01",
      "expiryDate": "2026-09-01",
      "medications": [
        {
          "name": "Amoxicillin",
          "strength": "500mg",
          "form": "capsule",
          "quantity": 21,
          "unit": "capsules",
          "frequency": "3x daily",
          "durationDays": 7,
          "instructions": "Complete the full course",
          "refills": 1
        }
      ]
    }
    ''');

    expect(payload, isNotNull);
    expect(payload!.prescriberName, 'Dr. Jane Smith');
    expect(payload.issuedDate, DateTime.parse('2026-08-01'));
    expect(payload.expiryDate, DateTime.parse('2026-09-01'));
    expect(payload.medications, hasLength(1));
    final med = payload.medications.first;
    expect(med.medicationName, 'Amoxicillin');
    expect(med.strength, '500mg');
    expect(med.quantity, 21);
    expect(med.refillsAllowed, 1);
  });

  test('fills in sensible defaults for a minimal payload', () {
    final payload = parseScannedPrescriptionPayload('''
    { "medications": [ { "name": "Ibuprofen" } ] }
    ''');

    expect(payload, isNotNull);
    expect(payload!.prescriberName, isNull);
    expect(payload.medications.single.medicationName, 'Ibuprofen');
    expect(payload.medications.single.quantity, 1);
    expect(payload.medications.single.durationDays, 30);
    expect(payload.expiryDate.difference(payload.issuedDate).inDays, 30);
  });

  test('returns null for invalid JSON', () {
    expect(parseScannedPrescriptionPayload('not json at all'), isNull);
  });

  test('returns null when the JSON is not an object', () {
    expect(parseScannedPrescriptionPayload('[1, 2, 3]'), isNull);
  });

  test('returns null when medications is missing', () {
    expect(parseScannedPrescriptionPayload('{"prescriberName": "Dr. Smith"}'), isNull);
  });

  test('returns null when medications is empty', () {
    expect(parseScannedPrescriptionPayload('{"medications": []}'), isNull);
  });

  test('skips a medication entry with no name and returns null if none remain', () {
    expect(parseScannedPrescriptionPayload('{"medications": [{"strength": "10mg"}]}'), isNull);
  });

  test('skips an unnamed entry but keeps valid ones among several', () {
    final payload = parseScannedPrescriptionPayload('''
    {
      "medications": [
        {"strength": "10mg"},
        {"name": "Metformin", "strength": "500mg"}
      ]
    }
    ''');

    expect(payload, isNotNull);
    expect(payload!.medications, hasLength(1));
    expect(payload.medications.single.medicationName, 'Metformin');
  });
}
