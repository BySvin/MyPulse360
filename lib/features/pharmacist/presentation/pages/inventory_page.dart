import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/add_medicine_sheet.dart';
import '../widgets/inventory_row.dart';

/// F3 — Inventory: drawn at tablet width (768pt), since Fatima works from
/// an Android tablet at the counter (§9.1 two-column rules apply).
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final items = ref.watch(inventoryProvider(user.id));
    final lowStock = items.where((i) => i.isLowStock).length;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('Inventory', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  lowStock == 0 ? 'All stock levels healthy' : '$lowStock item(s) at or below reorder level',
                  style: TextStyle(
                    fontSize: 12,
                    color: lowStock == 0 ? colors.textSecondary : colors.warningText,
                  ),
                ),
                const SizedBox(height: 14),
                // Custom medicine restock — registers a brand-new medication,
                // distinct from the per-item "+" restock on existing rows.
                InkWell(
                  onTap: () => showAddMedicineSheet(context, ref, user.id),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.patientAccent.withValues(alpha: 0.08),
                      border: Border.all(color: colors.patientAccent.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.patientAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom Medicine Restock',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: colors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Register a medication that isn't in inventory yet",
                                style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: colors.patientAccent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const EmptyStateView(title: 'No inventory items', icon: Icons.inventory_2_outlined)
                else if (isWide)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.6,
                    children: [for (final item in items) InventoryRow(item: item)],
                  )
                else
                  Column(
                    children: [
                      for (final item in items) ...[
                        InventoryRow(item: item),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
