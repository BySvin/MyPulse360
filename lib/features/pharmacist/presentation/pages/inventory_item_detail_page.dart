import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/inventory_batch.dart';
import '../providers/inventory_providers.dart';
import '../widgets/add_batch_sheet.dart';
import '../widgets/log_wastage_sheet.dart';
import '../widgets/stock_level_badge.dart';

/// All batches of one medication — quantity, expiry, cost, and supplier are
/// per-batch, not per-medication, so this is where that detail actually
/// lives (the Inventory list only shows the rolled-up total).
class InventoryItemDetailPage extends ConsumerWidget {
  const InventoryItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final locationId = ref.watch(selectedLocationProvider);
    final items = ref.watch(inventoryProvider(locationId));
    final matches = items.where((i) => i.id == itemId);
    if (matches.isEmpty) {
      return const Scaffold(body: Center(child: Text('Medication not found')));
    }
    final item = matches.first;
    final stock = ref.watch(itemStockProvider(item));
    final batches = ref.watch(batchesProvider(itemId));

    return Scaffold(
      appBar: LargeTitleAppBar(title: '${item.medicationName} ${item.strength}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stock.totalQuantity} in stock', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        '${item.form} · reorder at ${item.reorderLevel}${item.barcode != null ? ' · ${item.barcode}' : ''}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                StockLevelBadge(stock: stock),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Batches', style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                onPressed: () => showAddBatchSheet(context, ref, item),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Batch'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (batches.isEmpty)
            const EmptyStateView(title: 'No batches on file', icon: Icons.inventory_2_outlined)
          else
            for (final batch in batches) ...[
              _BatchTile(batch: batch),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _BatchTile extends ConsumerWidget {
  const _BatchTile({required this.batch});

  final InventoryBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final suppliers = ref.watch(suppliersProvider);
    String? supplierName;
    if (batch.supplierId != null) {
      for (final s in suppliers) {
        if (s.id == batch.supplierId) {
          supplierName = s.name;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: batch.isExpired
              ? colors.danger.withValues(alpha: 0.4)
              : batch.isExpiringWithin(kExpiringSoonDays)
                  ? colors.warning.withValues(alpha: 0.4)
                  : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(batch.batchNumber, style: Theme.of(context).textTheme.titleSmall),
              if (batch.isExpired)
                const StatusBadge(label: 'Expired', tone: StatusTone.danger)
              else if (batch.isExpiringWithin(kExpiringSoonDays))
                const StatusBadge(label: 'Expiring soon', tone: StatusTone.warning),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${batch.quantity} of ${batch.initialQuantity} remaining · expires ${DateFormatters.short(batch.expiryDate)}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${batch.unitCost.toStringAsFixed(2)} / unit${supplierName != null ? ' · $supplierName' : ''}',
            style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: batch.quantity <= 0 ? null : () => showLogWastageSheet(context, ref, batch),
              child: const Text('Log Wastage'),
            ),
          ),
        ],
      ),
    );
  }
}
