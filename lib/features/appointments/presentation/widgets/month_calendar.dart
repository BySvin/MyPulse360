import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../providers/appointments_providers.dart';

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Full month-grid date picker — replaces the old horizontal day-strip.
/// Each day shows a dot: green if the doctor has open slots that day, grey
/// if fully booked/in the past. Matches the P5 "calendar + slot grid"
/// reference exactly.
class MonthCalendar extends ConsumerStatefulWidget {
  const MonthCalendar({
    super.key,
    required this.doctorId,
    required this.selectedDate,
    required this.onSelected,
  });

  final String doctorId;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  ConsumerState<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<MonthCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    // Monday-first grid start.
    final leadingBlanks = (firstOfMonth.weekday - DateTime.monday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_displayedMonth),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final letter in _weekdayLetters)
                Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textTertiary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < totalCells; i++) _buildDayCell(context, gridStart.add(Duration(days: i)), todayDay),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendDot(color: colors.success, label: 'Slots available'),
              const SizedBox(width: 16),
              _LegendDot(color: colors.textTertiary, label: 'Unavailable'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day, DateTime todayDay) {
    final colors = context.colors;
    final inMonth = day.month == _displayedMonth.month;
    final isPast = day.isBefore(todayDay);
    final selected = _isSameDay(day, widget.selectedDate);

    final hasSlots = inMonth && !isPast
        ? ref.watch(availableSlotsProvider((doctorId: widget.doctorId, date: day))).any((s) => !s.isDisabled)
        : false;

    return GestureDetector(
      onTap: !inMonth || isPast ? null : () => widget.onSelected(day),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? colors.patientAccent : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: !inMonth || isPast
                      ? colors.textTertiary.withValues(alpha: 0.5)
                      : selected
                          ? Colors.white
                          : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 5,
                width: 5,
                child: !inMonth || isPast
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Colors.white
                              : hasSlots
                                  ? colors.success
                                  : colors.textTertiary.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
      ],
    );
  }
}
