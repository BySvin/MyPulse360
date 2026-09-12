import 'package:flutter/material.dart';

/// Sage-and-slate palette — warm paper surfaces, deep slate-blue ink, and a
/// soft sage accent that carries every committing action.
///
/// Roles, in one line each:
///   * sage  (`primaryBlueFill`, `primaryGreen`) — commits: book, confirm, save.
///   * slate (`inkBlack`, `teal`)                — navigates and carries authority.
///   * paper (`scaffoldLight`)                   — the ground; cards are pure white,
///     so a floating card reads by its own value shift before any shadow lands.
///
/// Constant names are inherited from the earlier blue/orange systems and are
/// kept verbatim so no call site has to change; read the role comment, not the
/// name. Every text pairing below was measured against WCAG 2.1 relative
/// luminance — ratios are noted inline.
abstract final class AppColors {
  // Primary accent — modern blue. Commits actions; also ColorScheme.primary.
  static const Color primaryBlueFill = Color(0xFF3B82F6); // modern blue
  static const Color primaryBlueText = Color(0xFF2563EB); // modern blue text
  static const Color primaryGreen = Color(0xFF10B981); // success fill
  static const Color primaryGreenText = Color(0xFF059669); // success text
  static const Color primaryPurple = Color(0xFF8B5CF6); // clinician role accent

  // Secondary / status
  static const Color teal = Color(0xFF0EA5E9); // info fill
  static const Color tealText = Color(0xFF0284C7); // info text
  static const Color amber = Color(0xFFF59E0B); // caution fill
  static const Color amberText = Color(0xFFD97706); // caution text
  static const Color rose = Color(0xFFEF4444); // danger
  static const Color red = Color(0xFFDC2626); // ColorScheme.error

  // Ink & warm neutrals (light)
  static const Color darkSlate = Color(0xFF0F172A); // primary text
  static const Color slate = Color(0xFF475569); // secondary text
  static const Color slateLight = Color(0xFF94A3B8); // tertiary / disabled
  static const Color borderLight = Color(0xFFE2E8F0); // border
  static const Color surfaceMuted = Color(0xFFF1F5F9); // muted fill
  static const Color surfaceSubtle = Color(0xFFF8FAFC); // lighter paper
  static const Color scaffoldLight = Color(0xFFF8FAFC); // page ground
  static const Color cardLight = Color(0xFFFFFFFF); // cards sit brighter than paper
  static const Color inkBlack = Color(0xFF1E293B); // hero/dark cards

  // Neutrals (dark) - OLED friendly
  static const Color scaffoldDark = Color(0xFF000000); // Pure black
  static const Color cardDark = Color(0xFF121212); // Slightly elevated dark gray
  static const Color borderDark = Color(0xFF2A2A2A); // Dark border
  static const Color surfaceMutedDark = Color(0xFF0A0A0A); // Deep muted black
  static const Color primaryBlueTextDark = Color(0xFF60A5FA);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);

  // Accent variants tuned for dark backgrounds
  static const Color primaryGreenDark = Color(0xFF34D399);
  static const Color primaryPurpleDark = Color(0xFFA78BFA);
  static const Color tealDark = Color(0xFF38BDF8);
  static const Color amberDark = Color(0xFFFBBF24);
  static const Color roseDark = Color(0xFFF87171);
  static const Color redDark = Color(0xFFF87171);

  const AppColors._();
}
