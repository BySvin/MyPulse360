import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/utils/date_formatters.dart';

/// Horizontal day-strip selector for booking a slot.
class AppointmentCalendar extends StatelessWidget {
  const AppointmentCalendar({
    super.key,
    required this.selectedDate,
    required this.onSelected,
    this.daysAhead = 14,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final int daysAhead;

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: daysAhead,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = DateTime(today.year, today.month, today.day).add(Duration(days: i));
          final selected = _isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () => onSelected(date),
            child: Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colors.patientAccent : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: selected ? colors.patientAccent : colors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormatters.weekdayShort(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.white70 : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatters.dayNum(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
