import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

/// iOS grouped-list row: leading icon chip, title, optional detail text or
/// trailing widget (switch, chevron).
class GroupedListTile extends StatelessWidget {
  const GroupedListTile({
    super.key,
    required this.title,
    this.leadingIcon,
    this.leadingColor,
    this.detail,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final String? detail;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titleColor = isDestructive ? colors.danger : colors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: (leadingColor ?? colors.patientAccent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(leadingIcon, size: 16, color: leadingColor ?? colors.patientAccent),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, color: titleColor),
              ),
            ),
            if (detail != null) ...[
              Text(detail!, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(width: 6),
            ],
            ?trailing,
            if (trailing == null && showChevron)
              Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
