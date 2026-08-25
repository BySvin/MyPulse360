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
import '../widgets/pharmacy_queue_tile.dart';

/// F1 — Pharmacist Dashboard: queue ordered by wait, amber past 30 min.
class PharmacistDashboardPage extends ConsumerWidget {
  const PharmacistDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final queue = ref.watch(pharmacyQueueProvider(user.id));
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
                if (!isDesktop) const SignOutIconButton(),
              ],
            ),
            const SizedBox(height: 2),
            Text(DateFormatters.full(DateTime.now()), style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 4),
            Text('${queue.length} in queue', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
            const SizedBox(height: 18),
            if (queue.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
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
