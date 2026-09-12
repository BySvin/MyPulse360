import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/time_slot.dart';

class TimeSlotChip extends StatelessWidget {
  const TimeSlotChip({super.key, required this.slot, this.onTap});

  final TimeSlot slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = slot.isDisabled;
    final selected = slot.isSelected;

    final colors = context.colors;

    final Color bg;
    final Color fg;
    final Color border;
    
    // Style matching the light-theme UI reference image, adapted for dark mode
    if (selected) {
      bg = colors.patientAccent.withValues(alpha: 0.1);
      fg = colors.patientAccent; // Blue/Accent
      border = colors.patientAccent;
    } else if (disabled) {
      bg = colors.surfaceMuted;
      fg = colors.textTertiary;
      border = colors.border;
    } else {
      bg = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
      fg = colors.textPrimary;
      border = colors.border;
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12), // Match screenshot rounded rect
          border: Border.all(color: border, width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              DateFormatters.time(slot.dateTime),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: fg,
                decoration: slot.isBooked ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

