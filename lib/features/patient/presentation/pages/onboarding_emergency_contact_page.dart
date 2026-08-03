import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/patient_providers.dart';
import '../widgets/onboarding_progress_bar.dart';

/// Onboarding step 2 of 5 — entirely optional; both fields can be left
/// blank and filled in later from Profile.
class OnboardingEmergencyContactPage extends ConsumerStatefulWidget {
  const OnboardingEmergencyContactPage({super.key});

  @override
  ConsumerState<OnboardingEmergencyContactPage> createState() => _OnboardingEmergencyContactPageState();
}

class _OnboardingEmergencyContactPageState extends ConsumerState<OnboardingEmergencyContactPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isNotEmpty || phone.isNotEmpty) {
      await ref.read(patientRepositoryProvider).updateProfile(
            user.id,
            emergencyContactName: name.isEmpty ? null : name,
            emergencyContactPhone: phone.isEmpty ? null : phone,
          );
      ref.read(patientDataRevisionProvider.notifier).state++;
    }
    if (!mounted) return;
    context.go(RoutePaths.onboardingHealthcarePreferences);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingProgressBar(step: 2),
              const SizedBox(height: 16),
              Text('Emergency contact', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                "Optional — someone we can reach if there's ever an emergency during a visit. "
                'You can add or change this anytime from your profile.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    AppTextField(label: 'Contact name', controller: _nameController),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Contact phone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Continue', onPressed: _continue, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
