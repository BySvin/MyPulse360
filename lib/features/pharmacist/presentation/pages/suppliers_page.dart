import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../providers/inventory_providers.dart';
import '../widgets/add_supplier_sheet.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final suppliers = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Suppliers',
        actions: [
          IconButton(
            onPressed: () => showAddSupplierSheet(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (suppliers.isEmpty)
            const EmptyStateView(title: 'No suppliers yet', icon: Icons.local_shipping_outlined)
          else
            for (final supplier in suppliers) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.clinicianAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_outlined, size: 18, color: colors.clinicianAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplier.name, style: Theme.of(context).textTheme.titleSmall),
                          if (supplier.contactName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              supplier.contactName!,
                              style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            ),
                          ],
                          if (supplier.phone != null || supplier.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              [if (supplier.phone != null) supplier.phone!, if (supplier.email != null) supplier.email!]
                                  .join(' · '),
                              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
