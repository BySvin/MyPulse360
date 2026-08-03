import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../providers/inventory_providers.dart';

class InventoryAnalyticsPage extends ConsumerWidget {
  const InventoryAnalyticsPage({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final summary = ref.watch(locationSummaryProvider(locationId));
    final wastageCost = ref.watch(wastageCostProvider(locationId));
    final topDispensed = ref.watch(topDispensedProvider(locationId));
    final items = ref.watch(inventoryProvider(locationId));
    final expiringItems = items.where((i) => ref.watch(itemStockProvider(i)).isExpiringSoon).toList();

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Analytics'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Inventory value',
                  value: '\$${summary.totalValue.toStringAsFixed(0)}',
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Wastage cost',
                  value: '\$${wastageCost.toStringAsFixed(0)}',
                  color: wastageCost > 0 ? colors.danger : colors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Low stock',
                  value: '${summary.lowStockCount}',
                  color: summary.lowStockCount == 0 ? colors.success : colors.warningText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Expiring soon',
                  value: '${summary.expiringSoonCount}',
                  color: summary.expiringSoonCount == 0 ? colors.success : colors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Top dispensed', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (topDispensed.isEmpty)
            const EmptyStateView(
              title: 'No dispensing activity yet',
              message: 'Top medications will appear here once prescriptions are dispensed.',
              icon: Icons.bar_chart_rounded,
            )
          else
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: colors.border),
              ),
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= topDispensed.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              topDispensed[i].key.medicationName,
                              style: TextStyle(fontSize: 9.5, color: colors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < topDispensed.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: topDispensed[i].value.toDouble(),
                            color: colors.clinicianAccent,
                            width: 22,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Expiring soon', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (expiringItems.isEmpty)
            Text('Nothing expiring in the next $kExpiringSoonDays days.', style: TextStyle(fontSize: 12.5, color: colors.textSecondary))
          else
            for (final item in expiringItems) ...[
              _ExpiringRow(itemName: '${item.medicationName} ${item.strength}', expiry: ref.watch(itemStockProvider(item)).nearestExpiry),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ExpiringRow extends StatelessWidget {
  const _ExpiringRow({required this.itemName, required this.expiry});

  final String itemName;
  final DateTime? expiry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.06),
        border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: colors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(itemName, style: TextStyle(fontSize: 12.5, color: colors.textPrimary))),
          if (expiry != null)
            Text(DateFormatters.short(expiry!), style: TextStyle(fontSize: 11.5, color: colors.danger)),
        ],
      ),
    );
  }
}
