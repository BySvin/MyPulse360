import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';
import '../widgets/appointment_card.dart';
import '../widgets/queue_status_view.dart';
import 'book_appointment_page.dart';

/// Appointments tab root — book / view / reschedule all live here. Live
/// queue tracking has its own dedicated tab.
class AppointmentsListPage extends ConsumerStatefulWidget {
  const AppointmentsListPage({super.key});

  @override
  ConsumerState<AppointmentsListPage> createState() =>
      _AppointmentsListPageState();
}

class _AppointmentsListPageState extends ConsumerState<AppointmentsListPage> {
  String _filter = 'Queue';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.id));

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Appointments',
        showBack: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookAppointmentPage()),
            ),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: AsyncSection(
        value: appointmentsAsync,
        data: (appointments) {
          final now = DateTime.now();
          final upcoming = appointments
              .where((a) => a.scheduledAt.isAfter(now))
              .toList();
          final past = appointments
              .where((a) => !a.scheduledAt.isAfter(now))
              .toList()
              .reversed
              .toList();
          final shown = _filter == 'Upcoming' ? upcoming : past;

          return Column(
            children: [
              Expanded(
                child: appointments.isEmpty
                    ? EmptyStateView(
                        title: 'No appointments yet',
                        message: 'Book your first appointment to get started.',
                        icon: Icons.calendar_month_outlined,
                        actionLabel: 'Book Appointment',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BookAppointmentPage(),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          CupertinoSlidingSegmentedControl<String>(
                            groupValue: _filter,
                            backgroundColor: colors.surfaceMuted,
                            thumbColor: colors.patientAccent,
                            children: {
                              'Queue': Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Queue',
                                  style: TextStyle(
                                    color: _filter == 'Queue'
                                        ? Colors.white
                                        : colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              'Upcoming': Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Upcoming',
                                  style: TextStyle(
                                    color: _filter == 'Upcoming'
                                        ? Colors.white
                                        : colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              'Past': Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Past',
                                  style: TextStyle(
                                    color: _filter == 'Past'
                                        ? Colors.white
                                        : colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            },
                            onValueChanged: (value) {
                              if (value != null) {
                                setState(() => _filter = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_filter == 'Queue')
                            const QueueStatusView()
                          else if (shown.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text(
                                  _filter == 'Upcoming'
                                      ? 'No upcoming appointments'
                                      : 'No past appointments',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < shown.length; i++) ...[
                              _AppointmentTile(appointment: shown[i])
                                  .animate()
                                  .fadeIn(delay: (i * 60).ms, duration: 240.ms)
                                  .slideY(
                                    begin: 0.08,
                                    end: 0,
                                    curve: Curves.easeOut,
                                  ),
                              const SizedBox(height: 10),
                            ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentTile extends ConsumerWidget {
  const _AppointmentTile({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref
        .watch(userProfileProvider(appointment.doctorId))
        .valueOrNull;
    return AppointmentCard(
      appointment: appointment,
      doctorName: doctor?.fullName ?? 'Doctor',
      onTap: () => context.push(RoutePaths.appointmentDetail(appointment.id)),
    );
  }
}
