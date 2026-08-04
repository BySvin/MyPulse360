import 'entities/prescription_item.dart';
import 'scanned_prescription_parser.dart';

/// Best-effort extraction from text OCR'd off a photo of a prescription or
/// medicine box — always reviewed and editable afterward, never treated as
/// ground truth. Only attempts the two things reliably printed on
/// packaging: a name guess and an expiry date; dosage/frequency/quantity
/// are left blank since boxes don't print those in any consistent,
/// guessable format.
ScannedPrescriptionPayload buildPayloadFromOcrText(String recognizedText) {
  final lines = recognizedText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  final now = DateTime.now();
  final expiryDate = _guessExpiryDate(lines) ?? now.add(const Duration(days: 30));

  return ScannedPrescriptionPayload(
    issuedDate: now,
    expiryDate: expiryDate,
    medications: [
      PrescriptionItem(
        id: 'scanned-item-0',
        medicationName: _guessName(lines),
        strength: '',
        form: 'tablet',
        quantity: 1,
        unit: 'units',
        frequency: 'As directed',
        durationDays: 30,
        instructions: '',
      ),
    ],
  );
}

final _dateKeywords = RegExp(r'\b(EXP|EXPIRY|EXPIRES?|BEST\s*BEFORE|BB|USE\s*BY|USE\s*BEFORE)\b', caseSensitive: false);

final _isoDatePattern = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
final _monthNamePattern = RegExp(
  r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s+(\d{4}|\d{2})\b',
  caseSensitive: false,
);
final _fullDatePattern = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');
final _monthYearPattern = RegExp(r'(\d{1,2})[/\-](\d{2,4})(?!\d)');

const _monthAbbrevs = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const _boilerplateWords = [
  'BATCH', 'LOT', 'MFG', 'MFD', 'EXP', 'NDC', 'RX', 'STORE', 'KEEP',
  'CHILDREN', 'WARNING', 'CAUTION', 'DIRECTIONS', 'MANUFACTURED',
];

String _guessName(List<String> lines) {
  for (final line in lines) {
    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 3) continue;
    if (_dateKeywords.hasMatch(line)) continue;
    final upper = line.toUpperCase();
    if (_boilerplateWords.any((w) => upper == w || upper.startsWith('$w '))) continue;
    return _truncate(line, 60);
  }
  return '';
}

DateTime? _guessExpiryDate(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    if (!_dateKeywords.hasMatch(lines[i])) continue;
    final onSameLine = _extractDate(lines[i]);
    if (onSameLine != null) return onSameLine;
    if (i + 1 < lines.length) {
      final onNextLine = _extractDate(lines[i + 1]);
      if (onNextLine != null) return onNextLine;
    }
  }
  for (final line in lines) {
    final date = _extractDate(line);
    if (date != null) return date;
  }
  return null;
}

DateTime? _extractDate(String line) {
  final iso = _isoDatePattern.firstMatch(line);
  if (iso != null) {
    return _tryBuildDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
  }

  final monthName = _monthNamePattern.firstMatch(line);
  if (monthName != null) {
    final month = _monthAbbrevs.indexOf(monthName.group(1)!.toUpperCase()) + 1;
    final year = _normalizeYear(int.parse(monthName.group(2)!));
    return _lastDayOfMonth(year, month);
  }

  final full = _fullDatePattern.firstMatch(line);
  if (full != null) {
    final a = int.parse(full.group(1)!);
    final b = int.parse(full.group(2)!);
    final year = _normalizeYear(int.parse(full.group(3)!));
    // Ambiguous day/month order in a plain numeric date — try month-first
    // (US convention) first, then fall back to day-first.
    return _tryBuildDate(year, a, b) ?? _tryBuildDate(year, b, a);
  }

  final monthYear = _monthYearPattern.firstMatch(line);
  if (monthYear != null) {
    final month = int.parse(monthYear.group(1)!);
    final year = _normalizeYear(int.parse(monthYear.group(2)!));
    if (month < 1 || month > 12) return null;
    return _lastDayOfMonth(year, month);
  }

  return null;
}

DateTime? _tryBuildDate(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

DateTime _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0);

int _normalizeYear(int year) => year < 100 ? 2000 + year : year;

String _truncate(String value, int maxLength) => value.length <= maxLength ? value : value.substring(0, maxLength);
