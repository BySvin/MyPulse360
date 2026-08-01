import 'package:flutter/material.dart';

/// Warm, high-contrast palette — cream surfaces, near-black ink, and a
/// single confident orange accent — replacing the original clinical-blue
/// system per the "meetgen"-style re-theme.
abstract final class AppColors {
  // Primary accent (was blue)
  static const Color primaryBlueFill = Color(0xFFFF6A3D); // warm orange
  static const Color primaryBlueText = Color(0xFFC2410C); // AA-safe burnt-orange for text/links
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color primaryGreenText = Color(0xFF047857);
  static const Color primaryPurple = Color(0xFF7C3AED);

  // Secondary / status
  static const Color teal = Color(0xFF06B6D4);
  static const Color tealText = Color(0xFF0E7490);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberText = Color(0xFFB45309);
  static const Color rose = Color(0xFFF43F5E);
  static const Color red = Color(0xFFEF4444);

  // Ink & warm neutrals (light)
  static const Color darkSlate = Color(0xFF1C1917); // primary text (warm near-black)
  static const Color slate = Color(0xFF78716C); // secondary text, warm gray
  static const Color slateLight = Color(0xFFA8A29E); // tertiary text
  static const Color borderLight = Color(0xFFE7E0D3); // warm hairline
  static const Color surfaceMuted = Color(0xFFEFE9DC); // cream surface
  static const Color surfaceSubtle = Color(0xFFF7F3E9); // lighter cream
  static const Color scaffoldLight = Color(0xFFF4EFE3); // page background — warm cream
  static const Color cardLight = Color(0xFFFFFDF8); // warm white card
  static const Color inkBlack = Color(0xFF1A1A1A); // hero/dark cards

  // Neutrals (dark) — warm charcoal instead of cool near-black
  static const Color scaffoldDark = Color(0xFF15130F);
  static const Color cardDark = Color(0xFF211E19);
  static const Color borderDark = Color(0xFF3A352C);
  static const Color surfaceMutedDark = Color(0xFF1B1815);
  static const Color primaryBlueTextDark = Color(0xFFFFA073); // ink lightens
  static const Color textPrimaryDark = Color(0xFFF7F3E9);
  static const Color textSecondaryDark = Color(0xFFAFA89C);

  // Accent variants tuned for dark backgrounds
  static const Color primaryGreenDark = Color(0xFF34D399);
  static const Color primaryPurpleDark = Color(0xFFA78BFA);
  static const Color tealDark = Color(0xFF22D3EE);
  static const Color amberDark = Color(0xFFFBBF24);
  static const Color roseDark = Color(0xFFFB7185);
  static const Color redDark = Color(0xFFF87171);

  const AppColors._();
}
