import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';

class QuickReplyChips extends StatelessWidget {
  const QuickReplyChips({super.key, required this.replies, required this.onSelect});

  final List<String> replies;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final reply in replies)
          ActionChip(
            label: Text(reply, style: const TextStyle(fontSize: 12)),
            backgroundColor: colors.patientAccent.withValues(alpha: 0.08),
            side: BorderSide(color: colors.patientAccent.withValues(alpha: 0.4)),
            labelStyle: TextStyle(color: colors.patientAccentText),
            onPressed: () => onSelect(reply),
          ),
      ],
    );
  }
}
