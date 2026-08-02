import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/presentation/providers/doctor_providers.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';
import '../widgets/appointment_card.dart';
import 'book_appointment_page.dart';

/// Appointments tab root — book / view / reschedule all live here, plus a
/// highlighted entry point into the dedicated Queue Status page.
class AppointmentsListPage extends ConsumerStatefulWidget {
  const AppointmentsListPage({super.key});

  @override
  ConsumerState<AppointmentsListPage> createState() => _AppointmentsListPageState();
}

class _AppointmentsListPageState extends ConsumerState<AppointmentsListPage> {
  String _filter = 'Upcoming';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final appointments = ref.watch(patientAppointmentsProvider(user.id));
    final now = DateTime.now();
    final upcoming = appointments.where((a) => a.scheduledAt.isAfter(now)).toList();
    final past = appointments.where((a) => !a.scheduledAt.isAfter(now)).toList().reversed.toList();
    final shown = _filter == 'Upcoming' ? upcoming : past;

    final todaysAppointment = appointments.where((a) =>
        a.scheduledAt.year == now.year &&
        a.scheduledAt.month == now.month &&
        a.scheduledAt.day == now.day &&
        a.status != AppointmentStatus.cancelled);
    int? queuePosition;
    if (todaysAppointment.isNotEmpty) {
      final appt = todaysAppointment.first;
      final queue = ref.watch(todaysQueueProvider(appt.doctorId));
      final idx = queue.indexWhere((a) => a.id == appt.id);
      if (idx >= 0) queuePosition = idx + 1;
    }

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _QueueHighlightCard(queuePosition: queuePosition),
          ),
          Expanded(
            child: appointments.isEmpty
                ? EmptyStateView(
                    title: 'No appointments yet',
                    message: 'Book your first appointment to get started.',
                    icon: Icons.calendar_month_outlined,
                    actionLabel: 'Book Appointment',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BookAppointmentPage()),
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
                          'Upcoming': Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Upcoming',
                              style: TextStyle(
                                color: _filter == 'Upcoming' ? Colors.white : colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          'Past': Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Past',
                              style: TextStyle(
                                color: _filter == 'Past' ? Colors.white : colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value != null) setState(() => _filter = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              _filter == 'Upcoming' ? 'No upcoming appointments' : 'No past appointments',
                              style: TextStyle(color: colors.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < shown.length; i++) ...[
                          _AppointmentTile(appointment: shown[i])
                              .animate()
                              .fadeIn(delay: (i * 60).ms, duration: 240.ms)
                              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueHighlightCard extends StatelessWidget {
  const _QueueHighlightCard({required this.queuePosition});

  final int? queuePosition;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => context.push(RoutePaths.patientQueueNumber),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inkBlack,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.patientAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.confirmation_number_rounded, color: colors.patientAccent, size: 20)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(end: 1.15, duration: 900.ms, curve: Curves.easeInOut),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    queuePosition != null ? "You're #$queuePosition in queue" : 'Queue Status',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    queuePosition != null ? 'Tap to see your live position' : "Check today's live queue when you're checked in",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTile extends ConsumerWidget {
  const _AppointmentTile({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(authRepositoryProvider).getUserById(appointment.doctorId);
    return AppointmentCard(
      appointment: appointment,
      doctorName: doctor?.fullName ?? 'Doctor',
      onTap: () => context.push(RoutePaths.appointmentDetail(appointment.id)),
    );
  }
}
