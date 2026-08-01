import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/time_slot.dart';

class TimeSlotChip extends StatelessWidget {
  const TimeSlotChip({super.key, required this.slot, this.onTap});

  final TimeSlot slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = slot.isDisabled;
    final selected = slot.isSelected;

    final Color bg;
    final Color fg;
    final Color border;
    if (selected) {
      bg = colors.patientAccent;
      fg = Colors.white;
      border = colors.patientAccent;
    } else if (disabled) {
      bg = colors.surfaceMuted;
      fg = colors.textTertiary;
      border = colors.border;
    } else {
      bg = Theme.of(context).cardTheme.color!;
      fg = colors.textPrimary;
      border = colors.border;
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: border),
        ),
        child: Text(
          DateFormatters.time(slot.dateTime),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: fg,
            decoration: slot.isBooked ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
