import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/health_dashboard_providers.dart';
import '../widgets/vital_sign_card.dart';

/// Dedicated Health Overview screen — the patient's full set of vitals in
/// one place, plus wearable sync, rather than the condensed dashboard card.
class HealthOverviewPage extends ConsumerStatefulWidget {
  const HealthOverviewPage({super.key});

  @override
  ConsumerState<HealthOverviewPage> createState() => _HealthOverviewPageState();
}

class _HealthOverviewPageState extends ConsumerState<HealthOverviewPage> {
  bool _appleHealthConnected = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final summaries = ref.watch(dashboardSummariesProvider(user.id));

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Health Overview'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _AppleHealthCard(
            connected: _appleHealthConnected,
            onChanged: (value) => setState(() => _appleHealthConnected = value),
          ),
          const SizedBox(height: 20),
          Text('Vital Signs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (summaries.isEmpty)
            const EmptyStateView(
              title: 'No readings yet',
              message: 'Log your first reading from the dashboard to see it here.',
              icon: Icons.monitor_heart_outlined,
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
                for (final summary in summaries)
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

class _AppleHealthCard extends StatelessWidget {
  const _AppleHealthCard({required this.connected, required this.onChanged});

  final bool connected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
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
                Text('Apple Health', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  connected ? 'Syncing steps, heart rate & weight' : 'Connect to auto-sync your vitals',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          CupertinoSwitch(value: connected, onChanged: onChanged, activeTrackColor: colors.patientAccent),
        ],
      ),
    );
  }
}
