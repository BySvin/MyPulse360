import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type system: Figtree for UI text — humanist, tall x-height, holds up
/// under Dynamic Type — and IBM Plex Mono for small data readouts (queue
/// numbers, dosages, timestamps) where digits must stay unambiguous.
abstract final class AppTypography {
  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    final base = GoogleFonts.figtreeTextTheme();
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.02,
            color: primaryText,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02,
            color: primaryText,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: primaryText,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
          bodyLarge: base.bodyLarge?.copyWith(color: primaryText),
          bodyMedium: base.bodyMedium?.copyWith(color: primaryText),
          bodySmall: base.bodySmall?.copyWith(color: secondaryText),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: secondaryText,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: secondaryText,
          ),
        )
        .apply(bodyColor: primaryText, displayColor: primaryText);
  }

  static TextStyle mono({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.slate,
    double? letterSpacing,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );

  const AppTypography._();
}
