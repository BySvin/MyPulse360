/// Hive box/key names. Only primitives are persisted this pass (session +
/// preference state) — clinical/business data lives in [MockDatabase] and
/// resets on relaunch.
abstract final class HiveBoxes {
  static const String settings = 'settings_box';

  static const String keyThemeMode = 'theme_mode';
  static const String keyCurrentUserId = 'current_user_id';
  static const String keySavedEmail = 'saved_email';
  static const String keyOnboardingComplete = 'onboarding_complete';

  const HiveBoxes._();
}
