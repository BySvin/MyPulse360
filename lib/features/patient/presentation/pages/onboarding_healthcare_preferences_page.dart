import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/presentation/widgets/app_text_field.dart';
import '../../../../shared/presentation/widgets/grouped_list.dart';
import '../../../../shared/presentation/widgets/grouped_list_tile.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/patient_providers.dart';
import '../widgets/onboarding_progress_bar.dart';

const _languages = ['English', 'Spanish', 'French', 'Arabic', 'Other'];

/// Onboarding step 3 of 5 — everything here is optional and editable later
/// from Profile. The clinic field renders as a single confirm card rather
/// than a picker, since this mock backend only has one clinic on file
/// today; the underlying field still supports more once they exist.
class OnboardingHealthcarePreferencesPage extends ConsumerStatefulWidget {
  const OnboardingHealthcarePreferencesPage({super.key});

  @override
  ConsumerState<OnboardingHealthcarePreferencesPage> createState() =>
      _OnboardingHealthcarePreferencesPageState();
}

class _OnboardingHealthcarePreferencesPageState
    extends ConsumerState<OnboardingHealthcarePreferencesPage> {
  final _insuranceController = TextEditingController();
  final _otherLanguageController = TextEditingController();
  String? _language;
  bool _notifyAppointments = true;
  bool _notifyPrescriptions = true;
  bool _notifyHealthTips = true;
  bool _saving = false;

  @override
  void dispose() {
    _insuranceController.dispose();
    _otherLanguageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final clinics = ref.read(mockDatabaseProvider).clinics;
    final clinic = clinics.isEmpty ? null : clinics.first;
    setState(() => _saving = true);
    final language = _language == 'Other' ? _otherLanguageController.text.trim() : _language;
    await ref.read(patientRepositoryProvider).updateProfile(
          user.id,
          preferredClinicId: clinic?.id,
          insuranceProvider: _insuranceController.text.trim().isEmpty ? null : _insuranceController.text.trim(),
          preferredLanguage: (language == null || language.isEmpty) ? null : language,
          notifyAppointments: _notifyAppointments,
          notifyPrescriptions: _notifyPrescriptions,
          notifyHealthTips: _notifyHealthTips,
        );
    ref.read(patientDataRevisionProvider.notifier).state++;
    if (!mounted) return;
    context.go(RoutePaths.onboardingWellnessGoals);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clinics = ref.watch(mockDatabaseProvider).clinics;
    final clinic = clinics.isEmpty ? null : clinics.first;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingProgressBar(step: 3),
              const SizedBox(height: 16),
              Text('Healthcare preferences', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'All optional — helps us tailor reminders and paperwork to you.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    Text('Your clinic', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: colors.patientAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_hospital_rounded, color: colors.patientAccent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clinic?.name ?? 'No clinic on file',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (clinic != null)
                                  Text(
                                    clinic.address,
                                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.check_circle, size: 18, color: colors.success),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(label: 'Insurance provider (optional)', controller: _insuranceController),
                    const SizedBox(height: 20),
                    Text('Preferred language', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final lang in _languages)
                          ChoiceChip(
                            label: Text(lang, style: const TextStyle(fontSize: 12)),
                            selected: _language == lang,
                            onSelected: (_) => setState(() => _language = _language == lang ? null : lang),
                            selectedColor: colors.patientAccent,
                            labelStyle: TextStyle(color: _language == lang ? Colors.white : colors.textPrimary),
                            backgroundColor: Theme.of(context).cardTheme.color,
                            side: BorderSide(color: colors.border),
                          ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _language != 'Other'
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: AppTextField(label: 'Tell us your language', controller: _otherLanguageController),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text('Notifications', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    GroupedList(
                      children: [
                        GroupedListTile(
                          title: 'Appointment reminders',
                          leadingIcon: Icons.event_available_outlined,
                          trailing: CupertinoSwitch(
                            value: _notifyAppointments,
                            activeTrackColor: colors.patientAccent,
                            onChanged: (v) => setState(() => _notifyAppointments = v),
                          ),
                        ),
                        GroupedListTile(
                          title: 'Prescription updates',
                          leadingIcon: Icons.medication_outlined,
                          trailing: CupertinoSwitch(
                            value: _notifyPrescriptions,
                            activeTrackColor: colors.patientAccent,
                            onChanged: (v) => setState(() => _notifyPrescriptions = v),
                          ),
                        ),
                        GroupedListTile(
                          title: 'Health tips',
                          leadingIcon: Icons.lightbulb_outline_rounded,
                          trailing: CupertinoSwitch(
                            value: _notifyHealthTips,
                            activeTrackColor: colors.patientAccent,
                            onChanged: (v) => setState(() => _notifyHealthTips = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Continue', onPressed: _finish, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
