import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/inventory_providers.dart';
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
