import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_theme.dart';

/// One bottom-tab entry: icon, label, and the accent color to use when
/// active (patient screens use blue, clinician screens use purple).
class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Role-aware bottom navigation shell wrapping a go_router
/// [StatefulNavigationShell]. The same shell widget serves all three
/// roles — only the [items] list and [accentColor] differ per role.
///
/// When [centerActionIcon] is set (patient only), the bar becomes a
/// floating frosted-glass pill with the action inlined among the regular
/// tabs (e.g. "quick book appointment") rather than a raised FAB. Doctor
/// and pharmacist keep the plain flush bar.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
    required this.items,
    this.accentColor,
    this.centerActionIcon,
    this.centerActionLabel = 'Plus',
    this.centerActionOnTap,
    this.centerActionInsertIndex = 2,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavItem> items;
  final Color? accentColor;
  final IconData? centerActionIcon;
  final String centerActionLabel;
  final VoidCallback? centerActionOnTap;

  /// Where the inline action sits among [items] (e.g. 2 = after the 2nd tab).
  final int centerActionInsertIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = accentColor ?? colors.patientAccent;
    final hasCenterAction = centerActionIcon != null;

    if (!hasCenterAction) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavTab(
                        item: items[i],
                        selected: i == navigationShell.currentIndex,
                        accent: accent,
                        onTap: () => navigationShell.goBranch(
                          i,
                          initialLocation: i == navigationShell.currentIndex,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Floating frosted-glass pill nav — dark chrome regardless of app
    // theme, echoing the ink-black hero cards used elsewhere.
    final slots = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i == centerActionInsertIndex) {
        slots.add(Expanded(
          child: _NavTab.action(
            icon: centerActionIcon!,
            label: centerActionLabel,
            onTap: centerActionOnTap,
          ),
        ));
      }
      slots.add(Expanded(
        child: _NavTab(
          item: items[i],
          selected: i == navigationShell.currentIndex,
          accent: accent,
          onTap: () => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
        ),
      ));
    }
    if (centerActionInsertIndex >= items.length) {
      slots.add(Expanded(
        child: _NavTab.action(
          icon: centerActionIcon!,
          label: centerActionLabel,
          onTap: centerActionOnTap,
        ),
      ));
    }

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.inkBlack.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(children: slots),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required NavItem this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  })  : icon = null,
        label = null;

  const _NavTab.action({required this.icon, required this.label, required this.onTap})
      : item = null,
        selected = false,
        accent = null;

  final NavItem? item;
  final bool selected;
  final Color? accent;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;

  static const _inactive = Color(0xFF9C978C);

  @override
  Widget build(BuildContext context) {
    final color = selected ? (accent ?? _inactive) : _inactive;
    final displayIcon = item != null ? (selected ? item!.selectedIcon : item!.icon) : icon!;
    final displayLabel = item?.label ?? label!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(displayIcon, size: 20, color: color),
          const SizedBox(height: 3),
          Text(
            displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
