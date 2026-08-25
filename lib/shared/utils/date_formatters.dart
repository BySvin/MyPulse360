import 'package:intl/intl.dart';

abstract final class DateFormatters {
  static final _dayMonth = DateFormat('EEEE, MMM d, yyyy');
  static final _shortDate = DateFormat('MMM d, yyyy');
  static final _time = DateFormat('h:mm a');
  static final _weekdayShort = DateFormat('EEE');
  static final _dayNum = DateFormat('d');
  static final _monthShort = DateFormat('MMM');

  /// Everything that comes out of the database is UTC — `db_rows.dart` parses
  /// every timestamp with `.toUtc()`. `DateFormat` formats a `DateTime` in
  /// whatever zone it already carries, so formatting one of those directly
  /// prints the UTC wall clock: a 9am clinic appointment (stored 01:00Z after
  /// migration 0024) would render as "1:00 AM" in Kuala Lumpur, and an evening
  /// timestamp would show the wrong calendar day entirely.
  ///
  /// Converting here rather than at each call site means a formatted time is
  /// local *by construction*. On a `DateTime` that is already local — the
  /// calendar's `_selectedDate`, for instance — `toLocal()` is a no-op, so
  /// this is safe for every caller.
  static DateTime _local(DateTime d) => d.toLocal();

  static String full(DateTime date) => _dayMonth.format(_local(date));
  static String short(DateTime date) => _shortDate.format(_local(date));
  static String time(DateTime date) => _time.format(_local(date));
  static String weekdayShort(DateTime date) =>
      _weekdayShort.format(_local(date));
  static String dayNum(DateTime date) => _dayNum.format(_local(date));
  static String monthShort(DateTime date) => _monthShort.format(_local(date));

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return short(date);
  }

  const DateFormatters._();
}
