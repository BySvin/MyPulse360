import 'package:equatable/equatable.dart';

/// The two real platform-level health data hubs a phone can sync through
/// — HealthKit on iOS, Health Connect/Google Fit on Android. Individual
/// wearables (Apple Watch, Fitbit, a smart scale, etc.) all feed into
/// whichever of these the phone runs, so connecting is modeled at the
/// platform level rather than as separate per-device integrations.
enum HealthPlatform {
  appleHealth,
  googleFit;

  String get label => switch (this) {
        HealthPlatform.appleHealth => 'Apple Health',
        HealthPlatform.googleFit => 'Google Fit',
      };
}

class HealthPlatformConnection extends Equatable {
  const HealthPlatformConnection({
    required this.patientId,
    required this.platform,
    required this.connectedAt,
    this.lastSyncedAt,
  });

  final String patientId;
  final HealthPlatform platform;
  final DateTime connectedAt;
  final DateTime? lastSyncedAt;

  HealthPlatformConnection copyWith({DateTime? lastSyncedAt}) {
    return HealthPlatformConnection(
      patientId: patientId,
      platform: platform,
      connectedAt: connectedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [patientId, platform, connectedAt, lastSyncedAt];
}
