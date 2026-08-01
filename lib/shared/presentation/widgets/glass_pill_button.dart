import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted "liquid glass" pill icon button, echoing the design's nav-bar
/// pill chrome. Used sparingly for floating icon controls over imagery.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.dark = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tint = dark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.55);
    final iconColor = dark ? Colors.white : const Color(0xFF1F2937);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: tint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: size * 0.5, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
