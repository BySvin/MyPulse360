import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/inventory_item.dart';
import '../pages/inventory_item_detail_page.dart';
import '../providers/inventory_providers.dart';
import 'stock_level_badge.dart';

class InventoryRow extends ConsumerWidget {
  const InventoryRow({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final stock = ref.watch(itemStockProvider(item));

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InventoryItemDetailPage(itemId: item.id)),
      ),
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
                  stock.nearestExpiry == null
                      ? '${stock.totalQuantity} in stock · reorder at ${item.reorderLevel}'
                      : '${stock.totalQuantity} in stock · expires ${DateFormatters.short(stock.nearestExpiry!)}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StockLevelBadge(stock: stock),
              if (stock.isExpiringSoon) ...[
                const SizedBox(height: 4),
                Text('Expiring soon', style: TextStyle(fontSize: 10, color: colors.danger)),
              ],
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: colors.textTertiary, size: 20),
        ],
      ),
    );
  }
}
