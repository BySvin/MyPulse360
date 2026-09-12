import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_theme.dart';
import '../providers/appointments_providers.dart';

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
    _displayedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final month = ref.watch(
      monthAvailabilityProvider((
        doctorId: widget.doctorId,
        month: _displayedMonth,
      )),
    );
    final monthByDay = {
      for (final record
          in month.valueOrNull ??
              const <({DateTime day, int openSlots, bool isOnLeave})>[])
        _dayKey(record.day): record,
    };

    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;

    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    // Sunday is 7 in Dart, we want 0=Sun, 1=Mon, ..., 6=Sat
    final firstWeekday = firstDayOfMonth.weekday % 7; 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Date & Time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a date and time that works for you',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_displayedMonth),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: colors.textPrimary, size: 20),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: Icon(Icons.chevron_left_rounded, color: colors.textPrimary),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: Icon(Icons.chevron_right_rounded, color: colors.textPrimary),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              // Weekday headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
                  return SizedBox(
                    width: 32,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textTertiary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              if (month.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(
                        monthAvailabilityProvider((
                          doctorId: widget.doctorId,
                          month: _displayedMonth,
                        )),
                      ),
                      child: const Text('Failed to load. Try again'),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: daysInMonth + firstWeekday,
                  itemBuilder: (context, index) {
                    if (index < firstWeekday) {
                      return const SizedBox.shrink();
                    }
                    
                    final dayDate = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month,
                      index - firstWeekday + 1,
                    );
                    
                    return _buildDayCell(
                      context,
                      dayDate,
                      todayDay,
                      monthByDay[_dayKey(dayDate)],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    DateTime todayDay,
    ({DateTime day, int openSlots, bool isOnLeave})? record,
  ) {
    final colors = context.colors;
    final isPast = day.isBefore(todayDay);
    final selected = _isSameDay(day, widget.selectedDate);
    final isToday = _isSameDay(day, todayDay);

    final isLoaded = !isPast && record != null;
    final hasSlots = record != null && record.openSlots > 0;
    final onLeave = record != null && record.isOnLeave;

    final bgColor = selected ? colors.patientAccent : Colors.transparent;
    
    // Determine text color
    Color textColor;
    if (selected) {
      textColor = Colors.white;
    } else if (isPast) {
      textColor = colors.textTertiary;
    } else if (onLeave) {
      textColor = colors.danger.withValues(alpha: 0.5);
    } else if (!isLoaded) {
      textColor = colors.textPrimary; // Default if not loaded yet
    } else if (!hasSlots) {
      textColor = colors.textTertiary;
    } else {
      textColor = colors.textPrimary;
    }

    return GestureDetector(
      onTap: isPast || !isLoaded
          ? null
          : () => widget.onSelected(day),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: isToday && !selected 
              ? Border.all(color: colors.patientAccent, width: 1.5) 
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected || isToday ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
