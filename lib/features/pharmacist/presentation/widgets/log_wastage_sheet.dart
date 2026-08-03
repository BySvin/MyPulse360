import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/wastage_record.dart';
import '../providers/inventory_providers.dart';

Future<void> showLogWastageSheet(BuildContext context, WidgetRef ref, InventoryBatch batch) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LogWastageSheet(batch: batch),
  );
}

class _LogWastageSheet extends ConsumerStatefulWidget {
  const _LogWastageSheet({required this.batch});

  final InventoryBatch batch;

  @override
  ConsumerState<_LogWastageSheet> createState() => _LogWastageSheetState();
}

class _LogWastageSheetState extends ConsumerState<_LogWastageSheet> {
  late final TextEditingController _quantityController;
  final _noteController = TextEditingController();
  WastageReason _reason = WastageReason.expired;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _quantity {
    final parsed = int.tryParse(_quantityController.text) ?? 0;
    return parsed.clamp(0, widget.batch.quantity);
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _quantity <= 0) return;
    setState(() => _saving = true);
    await ref.read(inventoryRepositoryProvider).recordWastage(
          batchId: widget.batch.id,
          quantity: _quantity,
          reason: _reason,
          recordedBy: user.id,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
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
              Text('Log Wastage', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Batch ${widget.batch.batchNumber} · ${widget.batch.quantity} remaining',
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Quantity wasted',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in WastageReason.values)
                    ChoiceChip(
                      label: Text(reason.label, style: const TextStyle(fontSize: 12)),
                      selected: _reason == reason,
                      onSelected: (_) => setState(() => _reason = reason),
                      selectedColor: colors.clinicianAccent,
                      labelStyle: TextStyle(color: _reason == reason ? Colors.white : colors.textPrimary),
                      backgroundColor: Theme.of(context).cardTheme.color,
                      side: BorderSide(color: colors.border),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Log Wastage',
                onPressed: _quantity <= 0 ? null : _save,
                loading: _saving,
                color: colors.clinicianAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
