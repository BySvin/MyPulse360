import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/app_card.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/domain/entities/consultation.dart' show Consultation;
import '../providers/pharmacist_providers.dart';

/// New Rx — completed consultations waiting for the pharmacist to turn the
/// doctor's diagnosis into an actual e-prescription.
class PharmacistPrescriptionsPage extends ConsumerWidget {
  const PharmacistPrescriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = ref.watch(awaitingPrescriptionProvider);

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Prescription', showBack: false),
      body: awaiting.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyStateView(
                title: 'All caught up',
                message:
                    "Completed visits waiting on a prescription will show up here.",
                icon: Icons.receipt_long_outlined,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final consultation in awaiting) ...[
                  _AwaitingRxTile(consultation: consultation),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _AwaitingRxTile extends ConsumerWidget {
  const _AwaitingRxTile({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final patient = ref
        .watch(userProfileProvider(consultation.patientId))
        .valueOrNull;
    final appointments =
        ref
            .watch(patientAppointmentsProvider(consultation.patientId))
            .valueOrNull ??
        const [];
    DateTime? scheduledAt;
    for (final a in appointments) {
      if (a.id == consultation.appointmentId) {
        scheduledAt = a.scheduledAt;
        break;
      }
    }

    return AppCard(
      onTap: () => context.push(RoutePaths.createPrescription(consultation.id)),
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
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  consultation.notes?.isNotEmpty == true
                      ? consultation.notes!
                      : 'No medication info from doctor',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scheduledAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormatters.full(scheduledAt),
                    style: TextStyle(fontSize: 11, color: colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
        ],
      ),
    );
  }
}
