import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../domain/entities/inventory_item.dart';

class StockLevelBadge extends StatelessWidget {
  const StockLevelBadge({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: item.isLowStock ? 'Reorder' : 'In stock',
      tone: item.isLowStock ? StatusTone.warning : StatusTone.success,
    );
  }
}
