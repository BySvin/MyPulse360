import 'package:intl/intl.dart';

abstract final class DateFormatters {
  static final _dayMonth = DateFormat('EEEE, MMM d, yyyy');
  static final _shortDate = DateFormat('MMM d, yyyy');
  static final _time = DateFormat('h:mm a');
  static final _weekdayShort = DateFormat('EEE');
  static final _dayNum = DateFormat('d');
  static final _monthShort = DateFormat('MMM');

  static String full(DateTime date) => _dayMonth.format(date);
  static String short(DateTime date) => _shortDate.format(date);
  static String time(DateTime date) => _time.format(date);
  static String weekdayShort(DateTime date) => _weekdayShort.format(date);
  static String dayNum(DateTime date) => _dayNum.format(date);
  static String monthShort(DateTime date) => _monthShort.format(date);

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
