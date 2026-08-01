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
import '../providers/doctor_providers.dart';
import '../widgets/patient_queue_tile.dart';

/// D1 — Doctor Dashboard: today's queue, purple clinician accent.
class DoctorDashboardPage extends ConsumerWidget {
  const DoctorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final queue = ref.watch(todaysQueueProvider(user.id));
    final remaining = queue.where((a) => a.status.name != 'completed').length;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 2),
                      Text(DateFormatters.full(DateTime.now()), style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.clinicianAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.clinicianAccent.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${queue.length} patients today',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.clinicianAccent),
                  ),
                ),
                if (!isDesktop) const SignOutIconButton(),
              ],
            ),
            const SizedBox(height: 4),
            Text('$remaining remaining', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
            const SizedBox(height: 18),
            if (queue.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyStateView(
                  title: 'No patients scheduled today',
                  message: 'Enjoy the quiet — your queue will appear here.',
                  icon: Icons.event_available_outlined,
                ),
              )
            else if (isDesktop)
              DesktopTable(
                columns: const [
                  DesktopTableColumn('Patient', flex: 3),
                  DesktopTableColumn('Time', flex: 2),
                  DesktopTableColumn('Type', flex: 2),
                  DesktopTableColumn('Reason', flex: 3),
                  DesktopTableColumn('Status', flex: 2),
                ],
                rows: [
                  for (final appt in queue)
                    Builder(builder: (context) {
                      final patient = ref.watch(authRepositoryProvider).getUserById(appt.patientId);
                      final name = patient?.fullName ?? 'Patient';
                      final status = QueueStatus.forAppointment(appt);
                      return DesktopTableRow(
                        onTap: () => context.push(RoutePaths.patientHistory(appt.patientId, appointmentId: appt.id)),
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
                            flex: 2,
                            child: Text(
                              DateFormatters.time(appt.scheduledAt),
                              style: TextStyle(fontSize: 13, color: colors.textSecondary),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              appt.appointmentType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: colors.textSecondary),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              appt.reasonForVisit ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: colors.textTertiary),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: StatusBadge(label: status.label, tone: status.tone),
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              )
            else
              for (final appt in queue) ...[
                Builder(builder: (context) {
                  final patient = ref.watch(authRepositoryProvider).getUserById(appt.patientId);
                  return PatientQueueTile(
                    appointment: appt,
                    patientName: patient?.fullName ?? 'Patient',
                    onTap: () => context.push(RoutePaths.patientHistory(appt.patientId, appointmentId: appt.id)),
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
