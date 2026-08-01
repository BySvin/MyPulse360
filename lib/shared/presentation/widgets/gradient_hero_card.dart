import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_shadows.dart';
import '../../../config/theme/app_theme.dart';

/// The "Health Overview" hero card pattern: white body with a green→teal
/// gradient accent line across the top.
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryGreen, AppColors.teal],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
