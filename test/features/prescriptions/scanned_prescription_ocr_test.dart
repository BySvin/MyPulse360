import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/prescriptions/domain/scanned_prescription_ocr.dart';

void main() {
  test('extracts an EXP keyword date in MM/YY form as end-of-month', () {
    final payload = buildPayloadFromOcrText('''
    Amoxicillin 500mg
    Batch AB1234
    EXP 08/28
    ''');

    expect(payload.expiryDate, DateTime(2028, 8, 31));
  });

  test('extracts an EXP keyword date on the following line', () {
    final payload = buildPayloadFromOcrText('''
    Paracetamol 500mg
    EXP
    12/2027
    ''');

    expect(payload.expiryDate, DateTime(2027, 12, 31));
  });

  test('extracts a month-name expiry date', () {
    final payload = buildPayloadFromOcrText('''
    Ibuprofen 200mg
    BEST BEFORE AUG 2028
    ''');

    expect(payload.expiryDate, DateTime(2028, 8, 31));
  });

  test('extracts an ISO-formatted expiry date', () {
    final payload = buildPayloadFromOcrText('''
    Metformin 500mg
    Expiry: 2028-08-31
    ''');

    expect(payload.expiryDate, DateTime(2028, 8, 31));
  });

  test('falls back to now + 30 days when no date-shaped text is found', () {
    final before = DateTime.now().add(const Duration(days: 30));
    final payload = buildPayloadFromOcrText('Just some text\nwith no dates at all');
    final after = DateTime.now().add(const Duration(days: 30));

    expect(payload.expiryDate.isAfter(before.subtract(const Duration(minutes: 1))), isTrue);
    expect(payload.expiryDate.isBefore(after.add(const Duration(minutes: 1))), isTrue);
  });

  test('guesses the medication name from the first readable, non-boilerplate line', () {
    final payload = buildPayloadFromOcrText('''
    123456789012
    Amoxicillin 500mg Capsules
    Batch AB1234
    EXP 08/28
    ''');

    expect(payload.medications.single.medicationName, 'Amoxicillin 500mg Capsules');
  });

  test('skips boilerplate and date-keyword lines when guessing the name', () {
    final payload = buildPayloadFromOcrText('''
    EXP 08/28
    BATCH NO AB1234
    MFG DATE 01/2026
    Metformin 500mg
    ''');

    expect(payload.medications.single.medicationName, 'Metformin 500mg');
  });

  test('returns a blank name when nothing readable was found', () {
    final payload = buildPayloadFromOcrText('123456789012\n9876543210');

    expect(payload.medications.single.medicationName, '');
  });

  test('always returns exactly one medication entry with default dosage fields', () {
    final payload = buildPayloadFromOcrText('Aspirin 100mg\nEXP 08/28');
    final item = payload.medications.single;

    expect(item.quantity, 1);
    expect(item.unit, 'units');
    expect(item.frequency, 'As directed');
    expect(item.durationDays, 30);
    expect(item.instructions, '');
  });
}
