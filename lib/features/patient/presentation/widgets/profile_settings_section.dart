import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/grouped_list.dart';
import '../../../../shared/presentation/widgets/grouped_list_tile.dart';

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
    return GroupedList(
      header: 'Preferences',
      children: [
        GroupedListTile(
          title: 'Dark Mode',
          leadingIcon: Icons.dark_mode_outlined,
          trailing: Switch(value: darkMode, onChanged: onDarkModeChanged),
        ),
        GroupedListTile(
          title: 'Notifications',
          leadingIcon: Icons.notifications_outlined,
          trailing: Switch(value: notificationsEnabled, onChanged: onNotificationsChanged),
        ),
      ],
    );
  }
}
