import 'package:flutter/material.dart';

import '../../domain/entities/time_slot.dart';
import 'time_slot_chip.dart';

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({super.key, required this.slots, required this.onSelect});

  final List<TimeSlot> slots;
  final ValueChanged<TimeSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final slot in slots)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 48 - 36) / 4, // Roughly 4 per row
            child: TimeSlotChip(slot: slot, onTap: () => onSelect(slot)),
          ),
      ],
    );
  }
}
