import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/allergy_banner.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/presentation/widgets/sticky_submit_bar.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../../prescriptions/domain/entities/prescription_item.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../providers/pharmacist_providers.dart';
import '../widgets/drug_interaction_alert.dart';
import '../widgets/prescription_item_form.dart';

/// Pharmacist turns a doctor's completed diagnosis into an actual
/// e-prescription — medication records now live here, not with the doctor.
class CreatePrescriptionPage extends ConsumerStatefulWidget {
  const CreatePrescriptionPage({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<CreatePrescriptionPage> createState() =>
      _CreatePrescriptionPageState();
}

class _CreatePrescriptionPageState
    extends ConsumerState<CreatePrescriptionPage> {
  final List<PrescriptionItem> _items = [];
  bool _submitting = false;

  Future<void> _submit(String patientId, String doctorId) async {
    setState(() => _submitting = true);
    await ref
        .read(prescriptionsRepositoryProvider)
        .create(
          Prescription(
            id: '',
            patientId: patientId,
            doctorId: doctorId,
            issuedDate: DateTime.now(),
            expiryDate: DateTime.now().add(const Duration(days: 30)),
            status: PrescriptionStatus.active,
            items: _items,
            source: PrescriptionSource.inApp,
            consultationId: widget.consultationId,
          ),
        );
    ref.read(prescriptionsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final awaiting = ref.watch(awaitingPrescriptionProvider);
    final matches = awaiting.where((c) => c.id == widget.consultationId);
    if (matches.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Consultation not found')),
      );
    }
    final consultation = matches.first;
    final patient = ref
        .watch(userProfileProvider(consultation.patientId))
        .valueOrNull;
    final profileAsync = ref.watch(
      patientProfileProvider(consultation.patientId),
    );

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'New Prescription'),
      body: AsyncSection(
        value: profileAsync,
        data: (profile) {
          // Interactions and allergies are computed from the patient's
          // current medications — this is a safety check the pharmacist
          // relies on, not decoration. It must never render "no
          // interactions" / "no allergies" from a profile that has not
          // arrived yet, which is why the whole page body waits on this
          // AsyncSection rather than falling back to an empty list.
          final allMedNames = <String>{
            ...?profile?.currentMedications.map((m) => m.split(' ').first),
            ..._items.map((i) => i.medicationName),
          }.toList();
          final interactions = ref
              .watch(prescriptionsRepositoryProvider)
              .checkInteractions(allMedNames);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      AvatarWidget(
                        name: patient?.fullName ?? 'Patient',
                        color: colors.clinicianAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient?.fullName ?? 'Patient',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if ((consultation.diagnosis ?? '').isNotEmpty)
                              Text(
                                consultation.diagnosis!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if ((consultation.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEDICATION INFO FROM DOCTOR',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: colors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consultation.notes!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                AllergyBanner(allergies: profile?.allergies ?? const []),
                const SizedBox(height: 20),
                Text(
                  'Medications',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                PrescriptionItemForm(
                  onAdd: (item) => setState(() => _items.add(item)),
                ),
                DrugInteractionAlert(interactions: interactions),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final item in _items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${item.medicationName} ${item.strength}'),
                      subtitle: Text(
                        '${item.frequency} · ${item.durationDays} days',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _items.remove(item)),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: StickySubmitBar(
        label: 'Issue Prescription',
        enabled: _items.isNotEmpty,
        onSubmit: () => _submit(consultation.patientId, consultation.doctorId),
        loading: _submitting,
      ),
    );
  }
}
