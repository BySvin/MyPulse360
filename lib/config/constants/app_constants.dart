abstract final class AppConstants {
  static const String appName = 'MyPulse360';

  /// Simulated network latency range for mock datasources, so loading
  /// states are actually exercised during manual verification.
  static const int mockLatencyMinMs = 200;
  static const int mockLatencyMaxMs = 600;

  /// Below this width, clinician screens (doctor/pharmacist) fall back to
  /// the mobile bottom-tab shell; at/above it they use the desktop sidebar
  /// shell. The patient app is mobile-only and doesn't use this.
  static const double desktopBreakpoint = 900;

  const AppConstants._();
}
