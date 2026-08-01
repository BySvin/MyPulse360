import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/secondary_button.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../prescriptions/domain/entities/prescription_item.dart';

class PrescriptionItemForm extends StatefulWidget {
  const PrescriptionItemForm({super.key, required this.onAdd});

  final ValueChanged<PrescriptionItem> onAdd;

  @override
  State<PrescriptionItemForm> createState() => _PrescriptionItemFormState();
}

class _PrescriptionItemFormState extends State<PrescriptionItemForm> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _frequency = TextEditingController();
  final _duration = TextEditingController(text: '7');
  final _instructions = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _frequency.dispose();
    _duration.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _add() {
    if (_name.text.trim().isEmpty) return;
    widget.onAdd(
      PrescriptionItem(
        id: generateId(),
        medicationName: _name.text.trim(),
        strength: _strength.text.trim().isEmpty ? '—' : _strength.text.trim(),
        form: 'tablet',
        quantity: (int.tryParse(_duration.text) ?? 7) * 2,
        unit: 'tablets',
        frequency: _frequency.text.trim().isEmpty ? 'As directed' : _frequency.text.trim(),
        durationDays: int.tryParse(_duration.text) ?? 7,
        instructions: _instructions.text.trim().isEmpty ? 'As directed' : _instructions.text.trim(),
      ),
    );
    _name.clear();
    _strength.clear();
    _frequency.clear();
    _instructions.clear();
    _duration.text = '7';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: _field('Medication', _name)),
              const SizedBox(width: 8),
              Expanded(child: _field('Strength', _strength)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field('Frequency', _frequency)),
              const SizedBox(width: 8),
              Expanded(child: _field('Days', _duration, numeric: true)),
            ],
          ),
          const SizedBox(height: 8),
          _field('Instructions', _instructions),
          const SizedBox(height: 10),
          SecondaryButton(label: 'Add Medication', icon: Icons.add, onPressed: _add, fullWidth: false),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool numeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
