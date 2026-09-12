import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/desktop_table.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/sign_out_icon_button.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/pharmacist_providers.dart';
import '../widgets/add_patient_dialog.dart';
import '../widgets/pharmacy_queue_tile.dart';
import '../widgets/temperature_input_dialog.dart';

/// F1 — Pharmacist Dashboard: queue ordered by wait, amber past 30 min.
class PharmacistDashboardPage extends ConsumerWidget {
  const PharmacistDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final queue = ref.watch(pharmacyQueueProvider(user.id));
    final appointments = ref.watch(pharmacistTodaysAppointmentsProvider);
    
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(user.fullName, style: Theme.of(context).textTheme.headlineMedium),
                ),
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddPatientDialog(),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Add Patient'),
                  style: FilledButton.styleFrom(backgroundColor: colors.clinicianAccent),
                ),
                const SizedBox(width: 8),
                if (!isDesktop) const SignOutIconButton(),
              ],
            ),
            const SizedBox(height: 2),
            Text(DateFormatters.full(DateTime.now()), style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 24),
            
            Text('Today\'s Appointments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Select a patient to record their body temperature', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 10),
            
            if (appointments.isEmpty)
              const EmptyStateView(
                title: 'No appointments',
                message: 'There are no appointments scheduled for today.',
                icon: Icons.event_available_outlined,
              )
            else
              for (final appt in appointments) ...[
                Builder(builder: (context) {
                  final patient = ref.watch(userProfileProvider(appt.patientId)).valueOrNull;
                  final name = patient?.fullName ?? 'Patient';
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colors.border),
                    ),
                    tileColor: Theme.of(context).cardTheme.color,
                    leading: AvatarWidget(name: name, size: 32, color: colors.clinicianAccent),
                    title: Text(name, style: Theme.of(context).textTheme.titleSmall),
                    subtitle: Text(appt.appointmentType, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    trailing: const Icon(Icons.thermostat_outlined),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => TemperatureInputDialog(
                          appointment: appt,
                          patientName: name,
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
              
            const SizedBox(height: 32),
            Text('Pharmacy Queue', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${queue.length} in queue', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
            const SizedBox(height: 10),
            if (queue.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: EmptyStateView(
                  title: 'Queue is empty',
                  message: 'Prescriptions awaiting verification will appear here.',
                  icon: Icons.inbox_outlined,
                ),
              )
            else if (isDesktop)
              DesktopTable(
                columns: const [
                  DesktopTableColumn('Patient', flex: 3),
                  DesktopTableColumn('Medications', flex: 4),
                  DesktopTableColumn('Wait', flex: 2),
                ],
                rows: [
                  for (final rx in queue)
                    Builder(builder: (context) {
                      final patient = ref.watch(userProfileProvider(rx.patientId)).valueOrNull;
                      final name = patient?.fullName ?? 'Patient';
                      final medNames = rx.items.map((i) => i.medicationName).join(', ');
                      final wait = QueueWait.forPrescription(rx);
                      return DesktopTableRow(
                        onTap: () => context.push(RoutePaths.verify(rx.id)),
                        cells: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                AvatarWidget(name: name, size: 28, color: colors.clinicianAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              medNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: colors.textSecondary),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: StatusBadge(label: wait.label, tone: wait.tone),
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              )
            else
              for (final rx in queue) ...[
                Builder(builder: (context) {
                  final patient = ref.watch(userProfileProvider(rx.patientId)).valueOrNull;
                  return PharmacyQueueTile(
                    prescription: rx,
                    patientName: patient?.fullName ?? 'Patient',
                    onTap: () => context.push(RoutePaths.verify(rx.id)),
                  );
                }),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
