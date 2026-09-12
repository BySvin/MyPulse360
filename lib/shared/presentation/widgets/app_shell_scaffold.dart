import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

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
class AppShellScaffold extends StatefulWidget {
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
  final int centerActionInsertIndex;

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  bool _isSidebarExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.accentColor ?? colors.patientAccent;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        body: Container(
          // Background color to contrast with the glass sidebar
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              _buildSidebar(context, accent),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    bottomLeft: Radius.circular(32),
                  ),
                  child: Container(
                    color: Theme.of(context).cardTheme.color ?? Colors.white,
                    child: widget.navigationShell,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile layout: floating bottom nav bar
    final slots = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.centerActionIcon != null && i == widget.centerActionInsertIndex) {
        slots.add(_NavTab.action(
          icon: widget.centerActionIcon!,
          label: widget.centerActionLabel,
          onTap: widget.centerActionOnTap,
        ));
      }
      slots.add(_NavTab(
        item: widget.items[i],
        selected: i == widget.navigationShell.currentIndex,
        accent: accent,
        onTap: () => widget.navigationShell.goBranch(
          i,
          initialLocation: i == widget.navigationShell.currentIndex,
        ),
      ));
    }
    if (widget.centerActionIcon != null && widget.centerActionInsertIndex >= widget.items.length) {
      slots.add(_NavTab.action(
        icon: widget.centerActionIcon!,
        label: widget.centerActionLabel,
        onTap: widget.centerActionOnTap,
      ));
    }

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: slots,
          ),
        ),
      ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildSidebar(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: _isSidebarExpanded ? 220 : 80,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15), // Glass effect background
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Logo & Collapse button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.eco, color: Colors.white, size: 24),
                      ),
                      if (_isSidebarExpanded)
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => setState(() => _isSidebarExpanded = false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Expanded expand button if collapsed
                if (!_isSidebarExpanded)
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () => setState(() => _isSidebarExpanded = true),
                  ),
                if (!_isSidebarExpanded) const SizedBox(height: 16),
                // Navigation Items
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = index == widget.navigationShell.currentIndex;
                      return _SidebarItem(
                        item: item,
                        isSelected: isSelected,
                        isExpanded: _isSidebarExpanded,
                        onTap: () => widget.navigationShell.goBranch(
                          index,
                          initialLocation: index == widget.navigationShell.currentIndex,
                        ),
                      );
                    },
                  ),
                ),
                // Optional center action for web
                if (widget.centerActionIcon != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FloatingActionButton(
                      elevation: 0,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      onPressed: widget.centerActionOnTap,
                      child: Icon(widget.centerActionIcon, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final NavItem item;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Colors based on selection to mimic the image
    final bgColor = isSelected ? Colors.white : Colors.transparent;
    final iconColor = isSelected ? Colors.black87 : Colors.white;
    final textColor = isSelected ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(isSelected ? item.selectedIcon : item.icon, color: iconColor, size: 24),
              if (isExpanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
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
    final activeColor = accent ?? Theme.of(context).primaryColor;
    final displayIcon = item != null ? (selected ? item!.selectedIcon : item!.icon) : icon!;
    final displayLabel = item?.label ?? label!;
    
    final onActiveColor = activeColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: selected
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(displayIcon, size: 24, color: selected ? onActiveColor : _inactive),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onActiveColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
