import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mypulse360/shared/utils/date_formatters.dart';

/// Every timestamp from the database is UTC (`db_rows.dart` parses with
/// `.toUtc()`), and `DateFormat` formats a `DateTime` in whatever zone it
/// already carries. So formatting a database value directly prints the UTC
/// wall clock — a 9am Kuala Lumpur appointment renders as "1:00 AM".
///
/// Migration 0024 moved slot generation into the clinic's timezone, which is
/// what makes this visible: slots are now stored at 01:00Z and *must* be
/// displayed as 09:00 local.
void main() {
  // 01:00 UTC is 09:00 in Kuala Lumpur (UTC+8) — the exact case that motivated
  // this. The assertions below do not hard-code that offset, so they hold
  // wherever the suite runs.
  final instant = DateTime.utc(2026, 8, 26, 1, 0);
  final offset = DateTime.now().timeZoneOffset;

  test('a UTC instant is formatted in local time, not UTC wall clock', () {
    expect(
      DateFormatters.time(instant),
      DateFormat('h:mm a').format(instant.toLocal()),
    );
  });

  test('formatting is offset-aware rather than printing the raw UTC clock', () {
    if (offset == Duration.zero) {
      // In a UTC environment the two are identical by definition, so this
      // assertion cannot distinguish the fix from the bug. Said out loud
      // rather than left as a green tick that means nothing.
      return;
    }
    final rawUtcClock = DateFormat('h:mm a').format(instant);
    expect(
      DateFormatters.time(instant),
      isNot(rawUtcClock),
      reason:
          'dropping toLocal() in DateFormatters would print the UTC wall '
          'clock and this is the assertion that catches it',
    );
  });

  test('an already-local DateTime is unchanged — toLocal() is a no-op', () {
    // The booking calendar builds `_selectedDate` locally and formats it with
    // the same helpers, so the conversion must not shift those.
    final local = DateTime(2026, 8, 26, 14, 30);
    expect(DateFormatters.time(local), DateFormat('h:mm a').format(local));
    expect(DateFormatters.short(local), DateFormat('MMM d, yyyy').format(local));
  });

  test('the calendar day follows local time across a UTC date boundary', () {
    // 2026-08-25 17:00Z is already 2026-08-26 in any zone east of UTC+7.
    final lateUtc = DateTime.utc(2026, 8, 25, 17, 0);
    expect(
      DateFormatters.short(lateUtc),
      DateFormat('MMM d, yyyy').format(lateUtc.toLocal()),
    );
  });
}
