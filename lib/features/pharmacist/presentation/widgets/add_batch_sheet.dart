import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';

/// Restocks a medication already on file with a new batch — distinct from
/// [showAddMedicineSheet], which registers a brand-new medication.
Future<void> showAddBatchSheet(BuildContext context, WidgetRef ref, InventoryItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddBatchSheet(item: item),
  );
}

class _AddBatchSheet extends ConsumerStatefulWidget {
  const _AddBatchSheet({required this.item});

  final InventoryItem item;

  @override
  ConsumerState<_AddBatchSheet> createState() => _AddBatchSheetState();
}

class _AddBatchSheetState extends ConsumerState<_AddBatchSheet> {
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController(text: '50');
  late final TextEditingController _costController;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  String? _supplierId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _costController = TextEditingController(text: widget.item.unitCost.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _batchNumberController.text.trim().isNotEmpty && (int.tryParse(_quantityController.text) ?? 0) > 0;

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await ref.read(inventoryRepositoryProvider).addBatch(
          itemId: widget.item.id,
          batchNumber: _batchNumberController.text.trim(),
          quantity: int.tryParse(_quantityController.text) ?? 0,
          expiryDate: _expiryDate,
          unitCost: double.tryParse(_costController.text) ?? widget.item.unitCost,
          supplierId: _supplierId,
        );
    ref.read(inventoryRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final suppliers = ref.watch(suppliersProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
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
                Text('Add Batch', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${widget.item.medicationName} ${widget.item.strength}',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _batchNumberController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Batch / lot number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Quantity received',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit cost',
                          prefixText: r'$',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickExpiry,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiry date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(
                    labelText: 'Supplier (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Add Batch', onPressed: _canSave ? _save : null, loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
