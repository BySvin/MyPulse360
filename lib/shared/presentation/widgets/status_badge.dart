import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

enum StatusTone { success, warning, danger, info, neutral }

/// Small pill badge for statuses like Active/Expiring/Expired, Confirmed,
/// wait-time flags, etc. Tinted as a fraction of the semantic color so it
/// reads correctly against both light and dark card surfaces.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final (Color fg, Color? tint) = switch (tone) {
      StatusTone.success => (colors.successText, colors.success),
      StatusTone.warning => (colors.warningText, colors.warning),
      StatusTone.danger => (colors.danger, colors.danger),
      StatusTone.info => (colors.infoText, colors.info),
      StatusTone.neutral => (scheme.onSurfaceVariant, null),
    };
    final bg = tint?.withValues(alpha: 0.14) ?? scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
