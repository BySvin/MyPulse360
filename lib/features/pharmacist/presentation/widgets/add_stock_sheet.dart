import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';

Future<void> showAddStockSheet(BuildContext context, WidgetRef ref, InventoryItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddStockSheet(item: item),
  );
}

const _presets = [10, 25, 50, 100];

class _AddStockSheet extends ConsumerStatefulWidget {
  const _AddStockSheet({required this.item});

  final InventoryItem item;

  @override
  ConsumerState<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<_AddStockSheet> {
  final _controller = TextEditingController(text: '25');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addStock() async {
    final qty = int.tryParse(_controller.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _saving = true);
    await ref
        .read(inventoryRepositoryProvider)
        .updateStock(widget.item.id, widget.item.currentStock + qty);
    ref.read(inventoryRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Add Stock', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.item.medicationName} ${widget.item.strength} · currently ${widget.item.currentStock}',
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity to add',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      label: Text('+$preset'),
                      selected: _controller.text == '$preset',
                      onSelected: (_) => setState(() => _controller.text = '$preset'),
                      selectedColor: colors.patientAccent,
                      labelStyle: TextStyle(
                        color: _controller.text == '$preset' ? Colors.white : colors.textPrimary,
                        fontSize: 12,
                      ),
                      backgroundColor: Theme.of(context).cardTheme.color,
                      side: BorderSide(color: colors.border),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Add to Stock', onPressed: _addStock, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
