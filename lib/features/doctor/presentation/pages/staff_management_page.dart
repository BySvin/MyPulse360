import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/staff_management_providers.dart';
import '../widgets/add_staff_sheet.dart';

/// Doctor-only screen: create Doctor/Pharmacist accounts and
/// deactivate/reactivate them. This is the only place staff accounts come
/// from — there is no staff self-signup anywhere in the app.
class StaffManagementPage extends ConsumerWidget {
  const StaffManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final staff = ref.watch(staffAccountsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Staff', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Doctor and pharmacist accounts for this clinic.',
                        style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showAddStaffSheet(context, ref, currentUser.clinicId),
                  style: FilledButton.styleFrom(backgroundColor: colors.clinicianAccent),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add Staff'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final staffUser in staff) ...[
              _StaffRow(user: staffUser, isSelf: staffUser.id == currentUser.id),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends ConsumerWidget {
  const _StaffRow({required this.user, required this.isSelf});

  final AppUser user;
  final bool isSelf;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final makeInactive = user.isActive;
    if (makeInactive) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Deactivate ${user.fullName}?',
        message: 'They will no longer be able to sign in until reactivated.',
        confirmLabel: 'Deactivate',
        isDestructive: true,
      );
      if (!confirmed) return;
    }
    await ref.read(authRepositoryProvider).setAccountActive(userId: user.id, isActive: !makeInactive);
    ref.read(staffAccountsRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          AvatarWidget(name: user.fullName, color: colors.clinicianAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text('(You)', style: TextStyle(fontSize: 11.5, color: colors.textTertiary)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(user.email, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusBadge(label: user.role.label, tone: StatusTone.info),
                    if (!user.isActive)
                      const StatusBadge(label: 'Deactivated', tone: StatusTone.danger)
                    else if (user.mustChangePassword)
                      const StatusBadge(label: 'Pending first sign-in', tone: StatusTone.warning),
                  ],
                ),
              ],
            ),
          ),
          if (!isSelf)
            CupertinoSwitch(
              value: user.isActive,
              activeTrackColor: colors.clinicianAccent,
              onChanged: (_) => _toggleActive(context, ref),
            ),
        ],
      ),
    );
  }
}
