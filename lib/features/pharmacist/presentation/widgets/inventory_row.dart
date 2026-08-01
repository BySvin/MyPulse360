import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../domain/entities/inventory_item.dart';
import 'add_stock_sheet.dart';
import 'stock_level_badge.dart';

class InventoryRow extends ConsumerWidget {
  const InventoryRow({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.clinicianAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.medication_rounded, size: 18, color: colors.clinicianAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.medicationName} ${item.strength}', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${item.currentStock} in stock · reorder at ${item.reorderLevel}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          StockLevelBadge(item: item),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => showAddStockSheet(context, ref, item),
            icon: Icon(Icons.add_circle_rounded, color: colors.patientAccent, size: 22),
            tooltip: 'Add stock',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
