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
            letterSpacing: -1.0, // negative tracking for large text
            height: 1.05, // tight leading
            color: primaryText,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
            color: primaryText,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
            height: 1.15,
            color: primaryText,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
            height: 1.15,
            color: primaryText,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
            height: 1.2,
            color: primaryText,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            height: 1.2,
            color: primaryText,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            height: 1.25,
            color: primaryText,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            height: 1.3,
            color: primaryText,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            height: 1.3,
            color: primaryText,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            letterSpacing: 0.15,
            height: 1.5, // looser leading for body
            color: primaryText,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            letterSpacing: 0.2,
            height: 1.5,
            color: primaryText,
          ),
          bodySmall: base.bodySmall?.copyWith(
            letterSpacing: 0.25,
            height: 1.5,
            color: secondaryText,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
            color: primaryText,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            color: secondaryText,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.35, // positive tracking for small text
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
