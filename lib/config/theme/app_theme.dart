import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

/// Semantic tokens not covered by [ColorScheme] — status colors, the two
/// role accents (patient blue vs. clinician purple), and surface tones that
/// differ from Material's default light/dark mapping.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successText,
    required this.warning,
    required this.warningText,
    required this.danger,
    required this.info,
    required this.infoText,
    required this.patientAccent,
    required this.patientAccentText,
    required this.clinicianAccent,
    required this.surfaceMuted,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
  });

  final Color success;
  final Color successText;
  final Color warning;
  final Color warningText;
  final Color danger;
  final Color info;
  final Color infoText;
  final Color patientAccent;
  final Color patientAccentText;
  final Color clinicianAccent;
  final Color surfaceMuted;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;

  static const light = AppSemanticColors(
    success: AppColors.primaryGreen,
    successText: AppColors.primaryGreenText,
    warning: AppColors.amber,
    warningText: AppColors.amberText,
    danger: AppColors.rose,
    info: AppColors.teal,
    infoText: AppColors.tealText,
    patientAccent: AppColors.primaryBlueFill,
    patientAccentText: AppColors.primaryBlueText,
    clinicianAccent: AppColors.primaryPurple,
    surfaceMuted: AppColors.surfaceMuted,
    surfaceSubtle: AppColors.surfaceSubtle,
    textPrimary: AppColors.darkSlate,
    textSecondary: AppColors.slate,
    textTertiary: AppColors.slateLight,
    border: AppColors.borderLight,
  );

  static const dark = AppSemanticColors(
    success: AppColors.primaryGreenDark,
    successText: AppColors.primaryGreenDark,
    warning: AppColors.amberDark,
    warningText: AppColors.amberDark,
    danger: AppColors.roseDark,
    info: AppColors.tealDark,
    infoText: AppColors.tealDark,
    patientAccent: AppColors.primaryBlueFill,
    patientAccentText: AppColors.primaryBlueTextDark,
    clinicianAccent: AppColors.primaryPurpleDark,
    surfaceMuted: AppColors.surfaceMutedDark,
    surfaceSubtle: AppColors.cardDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textSecondaryDark,
    border: AppColors.borderDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successText,
    Color? warning,
    Color? warningText,
    Color? danger,
    Color? info,
    Color? infoText,
    Color? patientAccent,
    Color? patientAccentText,
    Color? clinicianAccent,
    Color? surfaceMuted,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successText: successText ?? this.successText,
      warning: warning ?? this.warning,
      warningText: warningText ?? this.warningText,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      infoText: infoText ?? this.infoText,
      patientAccent: patientAccent ?? this.patientAccent,
      patientAccentText: patientAccentText ?? this.patientAccentText,
      clinicianAccent: clinicianAccent ?? this.clinicianAccent,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
      patientAccent: Color.lerp(patientAccent, other.patientAccent, t)!,
      patientAccentText: Color.lerp(
        patientAccentText,
        other.patientAccentText,
        t,
      )!,
      clinicianAccent: Color.lerp(clinicianAccent, other.clinicianAccent, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

/// iOS slide-and-parallax transitions with real edge-swipe-to-pop, applied
/// on every platform this app runs on (not just iOS) — part of the "real
/// Apple app" interaction feel requested for the whole app.
const _iosPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
  },
);

abstract final class AppTheme {
  static ThemeData light() {
    const semantic = AppSemanticColors.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlueFill,
      brightness: Brightness.light,
      primary: AppColors.primaryBlueFill,
      secondary: AppColors.teal,
      error: AppColors.red,
      surface: AppColors.cardLight,
    ).copyWith(surfaceTint: Colors.transparent);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffoldLight,
      textTheme: AppTypography.textTheme(
        semantic.textPrimary,
        semantic.textSecondary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: semantic.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: semantic.border, thickness: 1),
      pageTransitionsTheme: _iosPageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldLight,
        foregroundColor: semantic.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      extensions: const [semantic],
    );
  }

  static ThemeData dark() {
    const semantic = AppSemanticColors.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlueFill,
      brightness: Brightness.dark,
      primary: AppColors.primaryBlueFill,
      secondary: AppColors.tealDark,
      error: AppColors.redDark,
      surface: AppColors.cardDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffoldDark,
      textTheme: AppTypography.textTheme(
        semantic.textPrimary,
        semantic.textSecondary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: semantic.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: semantic.border, thickness: 1),
      pageTransitionsTheme: _iosPageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldDark,
        foregroundColor: semantic.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      extensions: const [semantic],
    );
  }

  const AppTheme._();
}
