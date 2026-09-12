import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/grouped_list.dart';
import '../../../../shared/presentation/widgets/grouped_list_tile.dart';
import '../pages/report_issue_page.dart';

class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.patientAccent;
    return GroupedList(
      header: 'Preferences',
      children: [
        GroupedListTile(
          title: 'Dark Mode',
          leadingIcon: Icons.dark_mode_outlined,
          trailing: CupertinoSwitch(
            value: darkMode,
            onChanged: onDarkModeChanged,
            activeTrackColor: accent,
          ),
        ),
        GroupedListTile(
          title: 'Notifications',
          leadingIcon: Icons.notifications_outlined,
          trailing: CupertinoSwitch(
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
            activeTrackColor: accent,
          ),
        ),
        GroupedListTile(
          title: 'Report an Issue',
          leadingIcon: Icons.bug_report_outlined,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportIssuePage()),
            );
          },
        ),
      ],
    );
  }
}
