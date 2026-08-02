import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';

/// Shared building blocks for the optional demographic/health fields
/// (blood type, gender, existing conditions) collected during Health
/// Profile Setup and re-editable later from Profile — kept in one place so
/// both screens render and resolve them identically.
const kBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];

const kGenders = ['Male', 'Female', 'Other', 'Prefer not to say'];

const kConditionOptions = ['Diabetes', 'High Blood Pressure', 'Asthma', 'Heart Condition', 'None', 'Other'];

/// Resolves the conditions picker's UI selection state into the flat
/// string list stored on [PatientProfile.chronicConditions].
List<String> resolveConditions(Set<String> selected, String otherText) {
  if (selected.isEmpty || selected.contains('None')) return const [];
  final list = selected.where((s) => s != 'Other').toList();
  final other = otherText.trim();
  if (selected.contains('Other') && other.isNotEmpty) list.add(other);
  return list;
}

/// Reverse of [resolveConditions] — maps a saved conditions list back into
/// picker state when opening the edit sheet with existing data.
({Set<String> selected, String otherText}) initialConditionsSelection(List<String> conditions) {
  final known = conditions.where(kConditionOptions.contains).toSet();
  final unknown = conditions.where((c) => !kConditionOptions.contains(c)).toList();
  if (unknown.isNotEmpty) known.add('Other');
  return (selected: known, otherText: unknown.join(', '));
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.options, required this.isSelected, required this.onTap});

  final List<String> options;
  final bool Function(String option) isSelected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option, style: const TextStyle(fontSize: 12)),
            selected: isSelected(option),
            onSelected: (_) => onTap(option),
            selectedColor: colors.patientAccent,
            labelStyle: TextStyle(color: isSelected(option) ? Colors.white : colors.textPrimary),
            backgroundColor: Theme.of(context).cardTheme.color,
            side: BorderSide(color: colors.border),
          ),
      ],
    );
  }
}

/// Single-select, tap-again-to-clear blood type picker.
class BloodTypeSelector extends StatelessWidget {
  const BloodTypeSelector({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChipRow(
      options: kBloodTypes,
      isSelected: (o) => o == value,
      onTap: (o) => onChanged(o == value ? null : o),
    );
  }
}

/// Single-select, tap-again-to-clear gender picker.
class GenderSelector extends StatelessWidget {
  const GenderSelector({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChipRow(
      options: kGenders,
      isSelected: (o) => o == value,
      onTap: (o) => onChanged(o == value ? null : o),
    );
  }
}

/// Multi-select conditions picker. "None" clears every other selection and
/// vice versa; "Other" reveals a free-text field via [otherController].
class ConditionsSelector extends StatelessWidget {
  const ConditionsSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.otherController,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final TextEditingController otherController;

  void _tap(String option) {
    final next = Set<String>.from(selected);
    if (option == 'None') {
      next
        ..clear()
        ..add('None');
    } else {
      next.remove('None');
      if (!next.remove(option)) next.add(option);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow(options: kConditionOptions, isSelected: selected.contains, onTap: _tap),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !selected.contains('Other')
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: otherController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Describe the condition',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
