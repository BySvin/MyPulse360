import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../domain/entities/patient_profile.dart';
import '../providers/patient_providers.dart';
import 'health_profile_fields.dart';

/// Bottom sheet for editing the full self-reported health profile —
/// everything collected during Health Profile Setup can be revisited here.
Future<void> showEditHealthProfileSheet(
  BuildContext context,
  WidgetRef ref,
  PatientProfile profile,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EditHealthProfileSheet(profile: profile),
  );
}

class _EditHealthProfileSheet extends ConsumerStatefulWidget {
  const _EditHealthProfileSheet({required this.profile});

  final PatientProfile profile;

  @override
  ConsumerState<_EditHealthProfileSheet> createState() => _EditHealthProfileSheetState();
}

class _EditHealthProfileSheetState extends ConsumerState<_EditHealthProfileSheet> {
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _otherConditionController;
  late DateTime? _dateOfBirth;
  late String? _gender;
  late String? _bloodType;
  late Set<String> _conditions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController(text: widget.profile.heightCm.toStringAsFixed(0));
    _weightController = TextEditingController(text: widget.profile.weightKg.toStringAsFixed(1));
    _allergiesController = TextEditingController(text: widget.profile.allergies.join(', '));
    _dateOfBirth = widget.profile.dateOfBirth;
    _gender = widget.profile.gender;
    _bloodType = widget.profile.bloodType;
    final initialConditions = initialConditionsSelection(widget.profile.chronicConditions);
    _conditions = initialConditions.selected;
    _otherConditionController = TextEditingController(text: initialConditions.otherText);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _otherConditionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final allergies = _allergiesController.text
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    await ref.read(patientRepositoryProvider).updateProfile(
          widget.profile.id,
          heightCm: double.tryParse(_heightController.text),
          weightKg: double.tryParse(_weightController.text),
          allergies: allergies,
          dateOfBirth: _dateOfBirth,
          gender: _gender,
          bloodType: _bloodType,
          chronicConditions: resolveConditions(_conditions, _otherConditionController.text),
        );
    ref.read(patientDataRevisionProvider.notifier).state++;
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                Text('Edit Health Profile', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'cm',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _allergiesController,
                  decoration: const InputDecoration(
                    labelText: 'Allergies',
                    hintText: 'e.g. Penicillin, Peanuts',
                    helperText: 'Separate multiple allergies with commas',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Date of birth', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: colors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dateOfBirth == null ? 'Not set' : DateFormat.yMMMd().format(_dateOfBirth!),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: _dateOfBirth == null ? colors.textTertiary : colors.textPrimary,
                            ),
                          ),
                        ),
                        if (_dateOfBirth != null)
                          GestureDetector(
                            onTap: () => setState(() => _dateOfBirth = null),
                            child: Icon(Icons.close_rounded, size: 16, color: colors.textTertiary),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Gender', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                GenderSelector(value: _gender, onChanged: (v) => setState(() => _gender = v)),
                const SizedBox(height: 16),
                Text('Blood type', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                BloodTypeSelector(value: _bloodType, onChanged: (v) => setState(() => _bloodType = v)),
                const SizedBox(height: 16),
                Text('Existing health conditions', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ConditionsSelector(
                  selected: _conditions,
                  onChanged: (v) => setState(() => _conditions = v),
                  otherController: _otherConditionController,
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Save Changes', onPressed: _save, loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
