import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../providers/inventory_providers.dart';
import '../widgets/add_medicine_sheet.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/inventory_row.dart';
import 'inventory_analytics_page.dart';
import 'inventory_item_detail_page.dart';
import 'suppliers_page.dart';

/// F3 — Inventory: location switcher, low-stock/expiring/value summary,
/// then the medication list. Each row now shows stock computed across that
/// medication's batches rather than a single flat count.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanToFind(BuildContext context, WidgetRef ref, String locationId) async {
    final code = await showBarcodeScanner(context);
    if (code == null || !context.mounted) return;
    final match = ref.read(inventoryRepositoryProvider).getItemByBarcode(locationId, code);
    if (match != null) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InventoryItemDetailPage(itemId: match.id)),
      );
    } else {
      if (!context.mounted) return;
      showAddMedicineSheet(context, ref, locationId, prefillBarcode: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clinics = ref.watch(mockDatabaseProvider).clinics;
    final selectedLocation = ref.watch(selectedLocationProvider);
    final items = ref.watch(inventoryProvider(selectedLocation));
    final summary = ref.watch(locationSummaryProvider(selectedLocation));

    final query = _searchController.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? items
        : items.where((i) => i.medicationName.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _scanToFind(context, ref, selectedLocation),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan barcode',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SuppliersPage()),
            ),
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Suppliers',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InventoryAnalyticsPage(locationId: selectedLocation)),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Analytics',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (clinics.length > 1) ...[
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: selectedLocation,
                    backgroundColor: colors.surfaceMuted,
                    thumbColor: colors.patientAccent,
                    children: {
                      for (final clinic in clinics)
                        clinic.id: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            clinic.name,
                            style: TextStyle(
                              color: selectedLocation == clinic.id ? Colors.white : colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                    },
                    onValueChanged: (value) {
                      if (value != null) ref.read(selectedLocationProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        label: 'Low stock',
                        value: '${summary.lowStockCount}',
                        tone: summary.lowStockCount == 0 ? colors.success : colors.warningText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        label: 'Expiring soon',
                        value: '${summary.expiringSoonCount}',
                        tone: summary.expiringSoonCount == 0 ? colors.success : colors.danger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        label: 'Total value',
                        value: '\$${summary.totalValue.toStringAsFixed(0)}',
                        tone: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search medications',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).cardTheme.color,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => showAddMedicineSheet(context, ref, selectedLocation),
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
                          decoration: BoxDecoration(color: colors.patientAccent, shape: BoxShape.circle),
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
                if (shown.isEmpty)
                  EmptyStateView(
                    title: items.isEmpty ? 'No inventory items' : 'No matches',
                    icon: Icons.inventory_2_outlined,
                  )
                else if (isWide)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.6,
                    children: [for (final item in shown) InventoryRow(item: item)],
                  )
                else
                  Column(
                    children: [
                      for (final item in shown) ...[
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tone)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
        ],
      ),
    );
  }
}
