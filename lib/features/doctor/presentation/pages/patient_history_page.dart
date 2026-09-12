import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/allergy_banner.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../../../prescriptions/presentation/widgets/prescription_card.dart';
import '../../domain/entities/consultation.dart';
import '../providers/doctor_providers.dart';
import '../widgets/sticky_submit_bar.dart';

const _medicationNoteHint = 'e.g. Needs Metformin 500mg refill, 2x daily';

/// Doctor-facing read view of a patient's prior visits, prescriptions, and
/// health trends. The doctor's role is review-only — diagnosing from
/// history, not documenting a consultation — so when opened from today's
/// queue ([appointmentId] set), the only action available is a plain
/// "Mark as Seen" that hands the visit off to The clinic assistant to prescribe.
class PatientHistoryPage extends ConsumerStatefulWidget {
  const PatientHistoryPage({
    super.key,
    required this.patientId,
    this.appointmentId,
  });

  final String patientId;
  final String? appointmentId;

  @override
  ConsumerState<PatientHistoryPage> createState() => _PatientHistoryPageState();
}

class _PatientHistoryPageState extends ConsumerState<PatientHistoryPage> {
  final _medicationNoteController = TextEditingController();
  bool _marking = false;

  @override
  void dispose() {
    _medicationNoteController.dispose();
    super.dispose();
  }

  Future<void> _markAsSeen(String appointmentId, String doctorId) async {
    setState(() => _marking = true);
    final existing = ref
        .read(doctorRepositoryProvider)
        .startOrGetConsultation(appointmentId, widget.patientId, doctorId);
    final consultation = Consultation(
      id: existing.id,
      appointmentId: existing.appointmentId,
      patientId: existing.patientId,
      doctorId: existing.doctorId,
      status: existing.status,
      notes: _medicationNoteController.text.trim(),
    );
    await ref.read(doctorRepositoryProvider).submitConsultation(consultation);
    ref.read(appointmentsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _marking = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final doctor = ref.watch(currentUserProvider);
    final patient = ref
        .watch(userProfileProvider(widget.patientId))
        .valueOrNull;
    final profileAsync = ref.watch(patientProfileProvider(widget.patientId));
    final consultations = ref.watch(patientHistoryProvider(widget.patientId));
    final prescriptions = ref.watch(
      patientPrescriptionsProvider(widget.patientId),
    );
    // Decorative: which visit is "today's pending one" and its date enrich
    // already-loaded consultation cards rather than being the page's core
    // content, so a still-loading appointment list just means those extras
    // stay hidden for a moment rather than the whole page blocking on it.
    final appointments =
        ref.watch(patientAppointmentsProvider(widget.patientId)).valueOrNull ??
        const <Appointment>[];

    DateTime? scheduledAtFor(String appointmentId) {
      for (final a in appointments) {
        if (a.id == appointmentId) return a.scheduledAt;
      }
      return null;
    }

    Appointment? pendingAppointment;
    if (widget.appointmentId != null) {
      for (final a in appointments) {
        if (a.id == widget.appointmentId &&
            a.status != AppointmentStatus.completed) {
          pendingAppointment = a;
          break;
        }
      }
    }
    
    Consultation? currentConsultation;
    if (pendingAppointment != null) {
      for (final c in consultations) {
        if (c.appointmentId == pendingAppointment.id) {
          currentConsultation = c;
          break;
        }
      }
    }

    return Scaffold(
      appBar: LargeTitleAppBar(title: patient?.fullName ?? 'Patient History'),
      body: AsyncSection(
        value: profileAsync,
        data: (profile) {
          final age = profile?.age;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              AppCard(
                child: Row(
                  children: [
                    AvatarWidget(
                      name: patient?.fullName ?? 'Patient',
                      size: 52,
                      color: colors.clinicianAccent,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient?.fullName ?? 'Patient',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (age != null) '$age yrs',
                              if (profile?.gender != null) profile!.gender!,
                              if (profile?.bloodType != null)
                                'Type ${profile!.bloodType}',
                            ].join(' · '),
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
              if (pendingAppointment != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.clinicianAccent.withValues(alpha: 0.08),
                    border: Border.all(
                      color: colors.clinicianAccent.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 16,
                            color: colors.clinicianAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Today's visit — ${pendingAppointment.appointmentType}"
                              '${pendingAppointment.reasonForVisit != null ? " · ${pendingAppointment.reasonForVisit}" : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (currentConsultation?.vitals.temperatureCelsius != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.thermostat, size: 18, color: colors.danger),
                              const SizedBox(width: 8),
                              Text(
                                'Body Temp: ${currentConsultation!.vitals.temperatureCelsius!.toStringAsFixed(1)} °C',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Logged by Assistant',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Medication Info for Pharmacy',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Optional — a quick note on what this patient needs. The clinic assistant '
                  'still enters the formal e-prescription.',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _medicationNoteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: _medicationNoteHint,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AllergyBanner(allergies: profile?.allergies ?? const []),
              if (profile != null && profile.chronicConditions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final condition in profile.chronicConditions)
                      Chip(
                        label: Text(
                          condition,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colors.surfaceSubtle,
                        side: BorderSide(color: colors.border),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Current Medications',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (profile == null || profile.currentMedications.isEmpty)
                const EmptyStateView(
                  title: 'No medications on file',
                  icon: Icons.medication_outlined,
                )
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var i = 0;
                        i < profile.currentMedications.length;
                        i++
                      ) ...[
                        if (i != 0) Divider(height: 20, color: colors.border),
                        Row(
                          children: [
                            Icon(
                              Icons.medication_rounded,
                              size: 18,
                              color: colors.clinicianAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                profile.currentMedications[i],
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Past Consultations',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (consultations.isEmpty)
                const EmptyStateView(
                  title: 'No prior consultations',
                  icon: Icons.history,
                )
              else
                for (final consultation in consultations) ...[
                  _ConsultationTile(
                    consultation: consultation,
                    scheduledAt: scheduledAtFor(consultation.appointmentId),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 24),
              Text(
                'Prescriptions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (prescriptions.isEmpty)
                const EmptyStateView(
                  title: 'No prescriptions on file',
                  icon: Icons.medication_outlined,
                )
              else
                for (final prescription in prescriptions) ...[
                  PrescriptionCard(prescription: prescription),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
      bottomNavigationBar: pendingAppointment == null || doctor == null
          ? null
          : StickySubmitBar(
              label: 'Send to Pharmacy',
              onSubmit: () => _markAsSeen(pendingAppointment!.id, doctor.id),
              loading: _marking,
            ),
    );
  }
}

class _ConsultationTile extends StatelessWidget {
  const _ConsultationTile({
    required this.consultation,
    required this.scheduledAt,
  });

  final Consultation consultation;
  final DateTime? scheduledAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = consultation.vitals;
    final hasVitals = v.systolicBp != null || v.heartRate != null || v.temperatureCelsius != null || v.weightKg != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                scheduledAt == null
                    ? 'Undated visit'
                    : DateFormatters.full(scheduledAt!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                consultation.status == ConsultationStatus.completed
                    ? 'Completed'
                    : 'In progress',
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ],
          ),
          if ((consultation.diagnosis ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              consultation.diagnosis!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
          if ((consultation.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              consultation.notes!,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ],
          if (hasVitals) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (v.temperatureCelsius != null)
                    _VitalBadge(icon: Icons.thermostat, label: '${v.temperatureCelsius!.toStringAsFixed(1)} \u00B0C'),
                  if (v.systolicBp != null && v.diastolicBp != null)
                    _VitalBadge(icon: Icons.favorite_border, label: '${v.systolicBp}/${v.diastolicBp} mmHg'),
                  if (v.heartRate != null)
                    _VitalBadge(icon: Icons.monitor_heart_outlined, label: '${v.heartRate} bpm'),
                  if (v.weightKg != null)
                    _VitalBadge(icon: Icons.monitor_weight_outlined, label: '${v.weightKg!.toStringAsFixed(1)} kg'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VitalBadge extends StatelessWidget {
  const _VitalBadge({required this.icon, required this.label});
  
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.colors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
