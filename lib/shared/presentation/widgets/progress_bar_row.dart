import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

class ProgressBarRow extends StatelessWidget {
  const ProgressBarRow({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
  });

  final double progress; // 0..1
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: height,
        backgroundColor: colors.surfaceMuted,
        valueColor: AlwaysStoppedAnimation(color ?? colors.info),
      ),
    );
  }
}
