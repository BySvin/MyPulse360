import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../providers/appointments_providers.dart';

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Full month-grid date picker — replaces the old horizontal day-strip.
/// Each day shows a dot: green if the doctor has open slots that day, grey
/// if fully booked/in the past, red if the doctor has approved leave that
/// day. Matches the P5 "calendar + slot grid" reference exactly.
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

    final firstOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    // Monday-first grid start.
    final leadingBlanks = (firstOfMonth.weekday - DateTime.monday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    // One call per calendar month, not one per day cell — per-day slot
    // queries would cost 31 round trips.
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // A failed month load must read as a failure, not as a quiet
          // "everything is unavailable" — that's indistinguishable from a
          // still-loading month otherwise: dotless cells, disabled taps, no
          // message, no way to recover short of leaving the page.
          if (month.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: colors.textTertiary,
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${month.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      monthAvailabilityProvider((
                        doctorId: widget.doctorId,
                        month: _displayedMonth,
                      )),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else ...[
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < totalCells; i++)
                  _buildDayCell(
                    context,
                    gridStart.add(Duration(days: i)),
                    todayDay,
                    monthByDay[_dayKey(gridStart.add(Duration(days: i)))],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendDot(color: colors.success, label: 'Slots available'),
                _LegendDot(color: colors.textTertiary, label: 'Unavailable'),
                _LegendDot(color: colors.danger, label: 'Doctor on leave'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    DateTime todayDay,
    ({DateTime day, int openSlots, bool isOnLeave})? record,
  ) {
    final colors = context.colors;
    final inMonth = day.month == _displayedMonth.month;
    final isPast = day.isBefore(todayDay);
    final selected = _isSameDay(day, widget.selectedDate);

    // While the month is still loading, `record` is null: render the cell as
    // neither open nor on-leave and disable the tap rather than lying about
    // availability.
    final isLoaded = inMonth && !isPast && record != null;
    final hasSlots = record != null && record.openSlots > 0;
    final onLeave = record != null && record.isOnLeave;

    return GestureDetector(
      onTap: !inMonth || isPast || !isLoaded
          ? null
          : () => widget.onSelected(day),
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
                              : onLeave
                              ? colors.danger
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
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
        ),
      ],
    );
  }
}
