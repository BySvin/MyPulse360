import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../domain/entities/patient_profile.dart';
import '../providers/patient_providers.dart';

/// Bottom sheet for editing the self-reported parts of a patient's health
/// profile (height, weight, allergies). Blood type and chronic conditions
/// are clinician-set, so they stay read-only elsewhere.
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController(text: widget.profile.heightCm.toStringAsFixed(0));
    _weightController = TextEditingController(text: widget.profile.weightKg.toStringAsFixed(1));
    _allergiesController = TextEditingController(text: widget.profile.allergies.join(', '));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    super.dispose();
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
              const SizedBox(height: 20),
              PrimaryButton(label: 'Save Changes', onPressed: _save, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
