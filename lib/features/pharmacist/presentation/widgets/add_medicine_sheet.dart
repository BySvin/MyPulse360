import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../providers/inventory_providers.dart';

const _forms = ['Tablet', 'Capsule', 'Liquid', 'Injection', 'Inhaler', 'Cream'];

/// Registers a brand-new medication into inventory — distinct from
/// [showAddStockSheet], which only tops up an item already on file.
Future<void> showAddMedicineSheet(BuildContext context, WidgetRef ref, String pharmacyId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddMedicineSheet(pharmacyId: pharmacyId),
  );
}

class _AddMedicineSheet extends ConsumerStatefulWidget {
  const _AddMedicineSheet({required this.pharmacyId});

  final String pharmacyId;

  @override
  ConsumerState<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends ConsumerState<_AddMedicineSheet> {
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  final _stockController = TextEditingController(text: '50');
  final _reorderController = TextEditingController(text: '20');
  final _costController = TextEditingController(text: '5.00');
  String _form = _forms.first;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _saving = false;

  bool get _canSave => _nameController.text.trim().isNotEmpty && _strengthController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _costController.dispose();
    super.dispose();
  }

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
    await ref.read(inventoryRepositoryProvider).addItem(
          pharmacyId: widget.pharmacyId,
          medicationName: _nameController.text.trim(),
          strength: _strengthController.text.trim(),
          form: _form.toLowerCase(),
          currentStock: int.tryParse(_stockController.text) ?? 0,
          reorderLevel: int.tryParse(_reorderController.text) ?? 0,
          unitCost: double.tryParse(_costController.text) ?? 0,
          expiryDate: _expiryDate,
        );
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
                Text('Add New Medicine', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  "Register a medication that isn't in inventory yet.",
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Medication name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _strengthController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Strength',
                          hintText: 'e.g. 500mg',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _form,
                        decoration: const InputDecoration(
                          labelText: 'Form',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [for (final f in _forms) DropdownMenuItem(value: f, child: Text(f))],
                        onChanged: (v) => setState(() => _form = v ?? _form),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Initial stock',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _reorderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reorder at',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickExpiry,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expiry',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(
                            '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Add Medicine',
                  onPressed: _canSave ? _save : null,
                  loading: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
