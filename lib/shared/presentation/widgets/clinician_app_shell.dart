import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_constants.dart';
import '../../../config/theme/app_theme.dart';
import 'app_shell_scaffold.dart';
import 'avatar_widget.dart';
import 'sign_out_icon_button.dart';

/// Desktop dashboard shell for the clinician roles (doctor, pharmacist):
/// a fixed sidebar with branded header, nav, and account footer, with
/// content centered in a max-width column — the "used at a desk in a web
/// browser" counterpart to the patient app's mobile bottom-tab shell.
///
/// Below [AppConstants.desktopBreakpoint] it falls back to the same
/// bottom-tab [AppShellScaffold] the patient app uses, so nothing breaks if
/// a clinician opens the link on a phone.
class ClinicianAppShell extends StatelessWidget {
  const ClinicianAppShell({
    super.key,
    required this.navigationShell,
    required this.items,
    required this.accentColor,
    required this.userName,
    required this.roleLabel,
    this.avatarUrl,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavItem> items;
  final Color accentColor;
  final String userName;
  final String roleLabel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;
    if (!isDesktop) {
      return AppShellScaffold(
        navigationShell: navigationShell,
        items: items,
        accentColor: accentColor,
      );
    }

    final colors = context.colors;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(right: BorderSide(color: colors.border)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [colors.success, colors.info]),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'MyPulse360',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: 12),
                  for (var i = 0; i < items.length; i++)
                    _SidebarItem(
                      item: items[i],
                      selected: i == navigationShell.currentIndex,
                      accent: accentColor,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                    ),
                  const Spacer(),
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        AvatarWidget(name: userName, size: 34, color: accentColor, imagePath: avatarUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(roleLabel, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                            ],
                          ),
                        ),
                        const SignOutIconButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: colors.surfaceMuted,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: navigationShell,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: selected ? accent : colors.textSecondary),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? accent : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
