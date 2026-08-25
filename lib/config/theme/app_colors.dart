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
  // Primary accent — sage. Commits actions; also ColorScheme.primary.
  static const Color primaryBlueFill = Color(0xFF3F6B55); // white on it: 6.09:1
  static const Color primaryBlueText = Color(0xFF3F6B55); // on paper: 5.59:1
  static const Color primaryGreen = Color(0xFF4F7A63); // success fill, 4.89:1 on white
  static const Color primaryGreenText = Color(0xFF3F6B55); // success text, 5.59:1
  static const Color primaryPurple = Color(0xFF46567F); // clinician role accent

  // Secondary / status
  static const Color teal = Color(0xFF4F6579); // info fill (muted slate-blue)
  static const Color tealText = Color(0xFF3E5163); // info text, 8.2:1 on paper
  static const Color amber = Color(0xFFB4761A); // caution fill
  static const Color amberText = Color(0xFF8A5A12); // caution text, 5.43:1
  static const Color rose = Color(0xFFB3261E); // danger, 6.00:1
  static const Color red = Color(0xFFB3261E); // ColorScheme.error

  // Ink & warm neutrals (light)
  static const Color darkSlate = Color(0xFF1B2A38); // primary text, 13.43:1
  static const Color slate = Color(0xFF4A5C6B); // secondary text, 6.35:1
  static const Color slateLight = Color(0xFF6B7C8A); // tertiary / disabled, 3.95:1
  static const Color borderLight = Color(0xFFE3DED4); // warm hairline
  static const Color surfaceMuted = Color(0xFFEFEDE7); // muted fill
  static const Color surfaceSubtle = Color(0xFFF3F1EB); // lighter paper
  static const Color scaffoldLight = Color(0xFFF7F5F0); // page ground — warm paper
  static const Color cardLight = Color(0xFFFFFFFF); // cards sit brighter than paper
  static const Color inkBlack = Color(0xFF2E4257); // hero/dark cards — slate

  // Neutrals (dark)
  static const Color scaffoldDark = Color(0xFF10181F);
  static const Color cardDark = Color(0xFF18242D);
  static const Color borderDark = Color(0xFF2A3A45);
  static const Color surfaceMutedDark = Color(0xFF16212A);
  static const Color primaryBlueTextDark = Color(0xFFA8C4AE); // 9.53:1 on scaffoldDark
  static const Color textPrimaryDark = Color(0xFFE9EEEA); // 15.25:1
  static const Color textSecondaryDark = Color(0xFFA7B8BD); // 8.73:1

  // Accent variants tuned for dark backgrounds
  static const Color primaryGreenDark = Color(0xFFA8C4AE);
  static const Color primaryPurpleDark = Color(0xFFA9B4DE);
  static const Color tealDark = Color(0xFF9DB3C4);
  static const Color amberDark = Color(0xFFD9A757);
  static const Color roseDark = Color(0xFFF0918A);
  static const Color redDark = Color(0xFFF0918A);

  const AppColors._();
}
