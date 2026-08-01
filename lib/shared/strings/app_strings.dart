/// Centralized user-facing copy. Keeping it here (rather than scattered as
/// literals) means swapping to `easy_localization`'s `.tr()` later is a
/// mechanical find-replace instead of a rearchitecture.
abstract final class AppStrings {
  static const String appName = 'MyPulse360';
  static const String genericErrorTitle = 'Something went wrong';
  static const String genericErrorMessage = 'Please try again in a moment.';
  static const String retry = 'Try again';

  const AppStrings._();
}
