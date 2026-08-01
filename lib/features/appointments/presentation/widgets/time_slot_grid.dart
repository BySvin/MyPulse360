import 'package:flutter/material.dart';

import '../../domain/entities/time_slot.dart';
import 'time_slot_chip.dart';

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({super.key, required this.slots, required this.onSelect});

  final List<TimeSlot> slots;
  final ValueChanged<TimeSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        for (final slot in slots)
          TimeSlotChip(slot: slot, onTap: () => onSelect(slot)),
      ],
    );
  }
}
