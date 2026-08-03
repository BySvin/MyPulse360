import 'dart:convert';

import 'entities/prescription_item.dart';

/// A prescriber's paper prescription, as decoded from a QR code or
/// barcode the patient scanned — this app's own JSON schema (there's no
/// universal standard for what a real pharmacy prints), documented here:
///
/// ```json
/// {
///   "prescriberName": "Dr. Jane Smith",
///   "issuedDate": "2026-08-01",
///   "expiryDate": "2026-09-01",
///   "medications": [
///     {
///       "name": "Amoxicillin",
///       "strength": "500mg",
///       "form": "capsule",
///       "quantity": 21,
///       "unit": "capsules",
///       "frequency": "3x daily",
///       "durationDays": 7,
///       "instructions": "Complete the full course",
///       "refills": 0
///     }
///   ]
/// }
/// ```
///
/// Only `medications` (non-empty, each with at least a `name`) is
/// required — everything else falls back to a reasonable default so a
/// partially-filled-out code still produces something useful.
class ScannedPrescriptionPayload {
  const ScannedPrescriptionPayload({
    required this.medications,
    required this.issuedDate,
    required this.expiryDate,
    this.prescriberName,
  });

  final String? prescriberName;
  final DateTime issuedDate;
  final DateTime expiryDate;
  final List<PrescriptionItem> medications;
}

/// Returns null (never throws) if [raw] isn't a recognizable prescription
/// payload — the caller shows a "couldn't read that code" message rather
/// than crash on arbitrary scanned content.
ScannedPrescriptionPayload? parseScannedPrescriptionPayload(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;

  final medicationsRaw = decoded['medications'];
  if (medicationsRaw is! List || medicationsRaw.isEmpty) return null;

  final medications = <PrescriptionItem>[];
  for (var i = 0; i < medicationsRaw.length; i++) {
    final entry = medicationsRaw[i];
    if (entry is! Map) continue;
    final name = (entry['name'] as Object?)?.toString().trim();
    if (name == null || name.isEmpty) continue;
    medications.add(
      PrescriptionItem(
        id: 'scanned-item-$i',
        medicationName: name,
        strength: (entry['strength'] as Object?)?.toString() ?? '',
        form: (entry['form'] as Object?)?.toString() ?? 'tablet',
        quantity: _asInt(entry['quantity']) ?? 1,
        unit: (entry['unit'] as Object?)?.toString() ?? 'units',
        frequency: (entry['frequency'] as Object?)?.toString() ?? 'As directed',
        durationDays: _asInt(entry['durationDays']) ?? 30,
        instructions: (entry['instructions'] as Object?)?.toString() ?? '',
        refillsAllowed: _asInt(entry['refills']) ?? 0,
      ),
    );
  }
  if (medications.isEmpty) return null;

  final issuedDate = _asDate(decoded['issuedDate']) ?? DateTime.now();
  final expiryDate = _asDate(decoded['expiryDate']) ?? issuedDate.add(const Duration(days: 30));
  final prescriberName = (decoded['prescriberName'] as Object?)?.toString().trim();

  return ScannedPrescriptionPayload(
    prescriberName: (prescriberName == null || prescriberName.isEmpty) ? null : prescriberName,
    issuedDate: issuedDate,
    expiryDate: expiryDate,
    medications: medications,
  );
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _asDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
