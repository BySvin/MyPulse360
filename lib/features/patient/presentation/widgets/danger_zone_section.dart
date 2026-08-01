import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/grouped_list.dart';
import '../../../../shared/presentation/widgets/grouped_list_tile.dart';

class DangerZoneSection extends StatelessWidget {
  const DangerZoneSection({super.key, required this.onLogout, required this.onDeleteAccount});

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GroupedList(
      header: 'Account',
      children: [
        GroupedListTile(
          title: 'Sign Out',
          leadingIcon: Icons.logout,
          leadingColor: colors.textSecondary,
          onTap: onLogout,
          showChevron: false,
        ),
        GroupedListTile(
          title: 'Delete Account',
          leadingIcon: Icons.delete_outline,
          leadingColor: colors.danger,
          isDestructive: true,
          onTap: onDeleteAccount,
          showChevron: false,
        ),
      ],
    );
  }
}
