import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_shadows.dart';
import '../../../config/theme/app_theme.dart';

/// White (or dark-surface) rounded card with the design's subtle elevation.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
        boxShadow: elevated ? AppShadows.card : AppShadows.none,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: card,
      ),
    );
  }
}
