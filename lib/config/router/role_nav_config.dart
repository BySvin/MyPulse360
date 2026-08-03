import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../shared/presentation/widgets/app_shell_scaffold.dart';
import 'route_paths.dart';

/// Per-role bottom-tab configuration, data-driven so the router/shell don't
/// need role-specific branching logic scattered around.
class RoleNavConfig {
  const RoleNavConfig({required this.items, required this.rootPath});

  final List<NavItem> items;
  final String rootPath;
}

const Map<UserRole, RoleNavConfig> kRoleNavConfig = {
  UserRole.patient: RoleNavConfig(
    rootPath: RoutePaths.patientDashboard,
    items: [
      NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
      NavItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month_rounded,
        label: 'Appts',
      ),
      NavItem(
        icon: Icons.confirmation_number_outlined,
        selectedIcon: Icons.confirmation_number_rounded,
        label: 'Queue',
      ),
      NavItem(
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
        label: 'AI Chat',
      ),
      NavItem(icon: Icons.medication_outlined, selectedIcon: Icons.medication_rounded, label: 'Rx'),
      NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
    ],
  ),
  UserRole.doctor: RoleNavConfig(
    rootPath: RoutePaths.doctorDashboard,
    items: [
      NavItem(
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard_rounded,
        label: 'Dashboard',
      ),
      NavItem(icon: Icons.badge_outlined, selectedIcon: Icons.badge_rounded, label: 'Staff'),
      NavItem(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today_rounded,
        label: 'Schedule',
      ),
    ],
  ),
  UserRole.pharmacist: RoleNavConfig(
    rootPath: RoutePaths.pharmacistDashboard,
    items: [
      NavItem(icon: Icons.groups_outlined, selectedIcon: Icons.groups_rounded, label: 'Queue'),
      NavItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'New Rx',
      ),
      NavItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: 'Inventory',
      ),
      NavItem(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today_rounded,
        label: 'Schedule',
      ),
    ],
  ),
};
