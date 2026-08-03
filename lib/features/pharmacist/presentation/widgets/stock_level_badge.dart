import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/status_badge.dart';
import '../providers/inventory_providers.dart';

class StockLevelBadge extends StatelessWidget {
  const StockLevelBadge({super.key, required this.stock});

  final ItemStock stock;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: stock.isLowStock ? 'Reorder' : 'In stock',
      tone: stock.isLowStock ? StatusTone.warning : StatusTone.success,
    );
  }
}
