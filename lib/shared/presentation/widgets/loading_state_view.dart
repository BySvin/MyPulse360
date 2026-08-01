import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

/// P10 — reusable loading state pattern.
class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: context.colors.patientAccent,
        strokeWidth: 2.5,
      ),
    );
  }
}

/// Skeleton block used inside cards while content loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
