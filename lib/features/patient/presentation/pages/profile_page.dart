import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../config/theme/theme_mode_provider.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/grouped_list.dart';
import '../../../../shared/presentation/widgets/grouped_list_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../health_dashboard/presentation/pages/health_overview_page.dart';
import '../providers/patient_providers.dart';
import '../widgets/danger_zone_section.dart';
import '../widgets/edit_health_profile_sheet.dart';
import '../widgets/profile_settings_section.dart';

/// P9 — Profile: grouped rows, toggles, danger zone.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _notificationsEnabled = true;

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: "You'll need to sign in again to access your account.",
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go(RoutePaths.login);
    }
  }

  Future<void> _confirmDelete(String patientId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'This permanently removes your profile and health data. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      await ref.read(patientRepositoryProvider).deleteAccount(patientId);
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final profile = ref.watch(patientProfileProvider(user.id)).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              AvatarWidget(
                name: user.fullName,
                size: 56,
                imagePath: user.avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (profile != null) ...[
            GroupedList(
              header: 'Health Profile',
              children: [
                GroupedListTile(
                  title: 'Vitals & Trends',
                  leadingIcon: Icons.monitor_heart_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HealthOverviewPage(),
                    ),
                  ),
                ),
                GroupedListTile(
                  title: 'Date of Birth',
                  leadingIcon: Icons.cake_outlined,
                  detail: profile.dateOfBirth == null
                      ? 'Not set'
                      : DateFormat.yMMMd().format(profile.dateOfBirth!),
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
                GroupedListTile(
                  title: 'Gender',
                  leadingIcon: Icons.wc_outlined,
                  detail: profile.gender ?? 'Not set',
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
                GroupedListTile(
                  title: 'Blood Type',
                  leadingIcon: Icons.bloodtype_outlined,
                  detail: profile.bloodType ?? 'Not set',
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
                GroupedListTile(
                  title: 'Height',
                  leadingIcon: Icons.straighten,
                  detail: '${profile.heightCm.toStringAsFixed(0)} cm',
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
                GroupedListTile(
                  title: 'Weight',
                  leadingIcon: Icons.monitor_weight_outlined,
                  detail: '${profile.weightKg.toStringAsFixed(1)} kg',
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
                GroupedListTile(
                  title: 'Allergies',
                  leadingIcon: Icons.warning_amber_rounded,
                  detail: profile.allergies.isEmpty
                      ? 'None'
                      : profile.allergies.join(', '),
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
                GroupedListTile(
                  title: 'Chronic Conditions',
                  leadingIcon: Icons.favorite_border,
                  detail: profile.chronicConditions.isEmpty
                      ? 'None'
                      : profile.chronicConditions.join(', '),
                  onTap: () =>
                      showEditHealthProfileSheet(context, ref, profile),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          ProfileSettingsSection(
            darkMode: themeMode == ThemeMode.dark,
            onDarkModeChanged: (v) => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            notificationsEnabled: _notificationsEnabled,
            onNotificationsChanged: (v) =>
                setState(() => _notificationsEnabled = v),
          ),
          const SizedBox(height: 20),
          DangerZoneSection(
            onLogout: _confirmLogout,
            onDeleteAccount: () => _confirmDelete(user.id),
          ),
        ],
      ),
    );
  }
}
