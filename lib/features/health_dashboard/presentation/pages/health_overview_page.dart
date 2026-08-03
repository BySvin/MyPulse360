import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/health_platform_connection.dart';
import '../providers/health_dashboard_providers.dart';
import '../widgets/vital_sign_card.dart';

/// Real device/platform auto-detection: on an actual iOS build this is
/// always Apple Health, on Android always Google Fit — individual
/// wearables (Apple Watch, Fitbit, a smart scale, a CGM, …) all sync
/// through whichever of these the phone runs, so that's the level this
/// integration connects at rather than per-device.
HealthPlatform get _devicePlatform => switch (defaultTargetPlatform) {
      TargetPlatform.iOS => HealthPlatform.appleHealth,
      TargetPlatform.android => HealthPlatform.googleFit,
      _ => HealthPlatform.appleHealth,
    };

bool get _isRealMobileDevice =>
    defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

/// Dedicated Health Overview screen — the patient's full set of vitals in
/// one place, plus a real (simulated) health-platform connection that
/// backfills and syncs device data. There is no actual HealthKit/Google
/// Fit credential wired up here — see the connect card's copy for what
/// that would take in a real deployment.
class HealthOverviewPage extends ConsumerWidget {
  const HealthOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final summaries = ref.watch(dashboardSummariesProvider(user.id));
    final connection = ref.watch(healthPlatformConnectionProvider(user.id));
    final vitals = summaries.where((s) => s.type.isCoreVital).toList();
    final activity = summaries.where((s) => !s.type.isCoreVital).toList();
    final hasActivityData = activity.any((s) => s.sparkline.isNotEmpty);

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Health Overview'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _HealthPlatformCard(patientId: user.id, connection: connection),
          const SizedBox(height: 20),
          Text('Vital Signs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final summary in vitals)
                VitalSignCard(
                  summary: summary,
                  onTap: () => context.push(RoutePaths.healthMetricDetail(summary.type.name)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Activity & Fitness', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Synced from your connected health platform.',
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (!hasActivityData)
            EmptyStateView(
              title: connection == null ? 'No device connected' : 'No activity data yet',
              message: connection == null
                  ? 'Connect a health platform above to see steps, sleep, and more.'
                  : 'Tap Sync Now above to pull in the latest readings.',
              icon: Icons.directions_walk_rounded,
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                for (final summary in activity)
                  VitalSignCard(
                    summary: summary,
                    onTap: () => context.push(RoutePaths.healthMetricDetail(summary.type.name)),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap any vital above to see its full trend, statistics, and insights.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthPlatformCard extends ConsumerStatefulWidget {
  const _HealthPlatformCard({required this.patientId, required this.connection});

  final String patientId;
  final HealthPlatformConnection? connection;

  @override
  ConsumerState<_HealthPlatformCard> createState() => _HealthPlatformCardState();
}

class _HealthPlatformCardState extends ConsumerState<_HealthPlatformCard> {
  HealthPlatform _pendingPlatform = _devicePlatform;
  bool _busy = false;

  Future<void> _connect(HealthPlatform platform) async {
    setState(() => _busy = true);
    await ref.read(healthMetricsRepositoryProvider).connectPlatform(widget.patientId, platform);
    ref.read(healthMetricsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    await ref.read(healthMetricsRepositoryProvider).disconnectPlatform(widget.patientId);
    ref.read(healthMetricsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    await ref.read(healthMetricsRepositoryProvider).syncNow(widget.patientId);
    ref.read(healthMetricsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final connection = widget.connection;
    final connected = connection != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.favorite, size: 20, color: colors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? connection.platform.label : _pendingPlatform.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? (connection.lastSyncedAt == null
                              ? 'Connected'
                              : 'Last synced ${DateFormatters.relative(connection.lastSyncedAt!)}')
                          : 'Connect to auto-sync steps, sleep, heart rate & more',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: connected,
                onChanged: _busy ? null : (v) => v ? _connect(_pendingPlatform) : _disconnect(),
                activeTrackColor: colors.patientAccent,
              ),
            ],
          ),
          if (!connected && !_isRealMobileDevice) ...[
            const SizedBox(height: 12),
            Text(
              "This build can't detect a real phone platform — pick which one to simulate:",
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final platform in HealthPlatform.values) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: Text(platform.label, style: const TextStyle(fontSize: 12)),
                      selected: _pendingPlatform == platform,
                      onSelected: (_) => setState(() => _pendingPlatform = platform),
                      selectedColor: colors.patientAccent,
                      labelStyle: TextStyle(
                        color: _pendingPlatform == platform ? Colors.white : colors.textPrimary,
                      ),
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                  if (platform != HealthPlatform.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
          if (connected) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Sync Now'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
