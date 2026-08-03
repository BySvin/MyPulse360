import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/router/role_nav_config.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/validators.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/patient_providers.dart';
import '../widgets/health_profile_fields.dart';
import '../widgets/onboarding_progress_bar.dart';

/// Onboarding step 5 of 5 — collects the data used to personalize the
/// dashboard (BMI, wellness insights). Height/weight are required; every
/// other field can be left blank and filled in later from Profile.
class HealthProfileSetupPage extends ConsumerStatefulWidget {
  const HealthProfileSetupPage({super.key});

  @override
  ConsumerState<HealthProfileSetupPage> createState() => _HealthProfileSetupPageState();
}

class _HealthProfileSetupPageState extends ConsumerState<HealthProfileSetupPage> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _otherConditionController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodType;
  Set<String> _conditions = {};
  bool _touched = false;
  bool _saving = false;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _otherConditionController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      Validators.positiveNumber(_heightController.text, field: 'Height', min: 50, max: 250) == null &&
      Validators.positiveNumber(_weightController.text, field: 'Weight', min: 20, max: 300) == null;

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _finish() async {
    setState(() => _touched = true);
    if (!_isFormValid) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    await ref.read(patientRepositoryProvider).updateProfile(
          user.id,
          heightCm: double.parse(_heightController.text.trim()),
          weightKg: double.parse(_weightController.text.trim()),
          dateOfBirth: _dateOfBirth,
          gender: _gender,
          bloodType: _bloodType,
          chronicConditions: resolveConditions(_conditions, _otherConditionController.text),
        );
    ref.read(patientDataRevisionProvider.notifier).state++;
    if (!mounted) return;
    context.go(kRoleNavConfig[UserRole.patient]!.rootPath);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final heightError = _touched
        ? Validators.positiveNumber(_heightController.text, field: 'Height', min: 50, max: 250)
        : null;
    final weightError = _touched
        ? Validators.positiveNumber(_weightController.text, field: 'Weight', min: 20, max: 300)
        : null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingProgressBar(step: 5),
              const SizedBox(height: 16),
              Text('Set up your health profile', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'This personalizes your dashboard — BMI, progress, and recommendations. '
                'Height and weight are required; everything else is optional and editable later.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Height (cm)',
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            errorText: heightError,
                            isValid: _touched && heightError == null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Weight (kg)',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            errorText: weightError,
                            isValid: _touched && weightError == null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Date of birth', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDateOfBirth,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 16, color: colors.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dateOfBirth == null
                                    ? 'Optional — tap to set'
                                    : DateFormat.yMMMd().format(_dateOfBirth!),
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
                    const SizedBox(height: 20),
                    Text('Gender', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    GenderSelector(value: _gender, onChanged: (v) => setState(() => _gender = v)),
                    const SizedBox(height: 20),
                    Text('Blood type', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    BloodTypeSelector(value: _bloodType, onChanged: (v) => setState(() => _bloodType = v)),
                    const SizedBox(height: 20),
                    Text('Existing health conditions', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ConditionsSelector(
                      selected: _conditions,
                      onChanged: (v) => setState(() => _conditions = v),
                      otherController: _otherConditionController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Finish setup', onPressed: _finish, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
