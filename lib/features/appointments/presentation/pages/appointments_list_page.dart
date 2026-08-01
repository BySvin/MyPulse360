import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';
import '../widgets/appointment_card.dart';
import 'book_appointment_page.dart';

/// Appointments tab root — upcoming/past list + entry point to P6.
class AppointmentsListPage extends ConsumerWidget {
  const AppointmentsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final appointments = ref.watch(patientAppointmentsProvider(user.id));
    final now = DateTime.now();
    final upcoming = appointments.where((a) => a.scheduledAt.isAfter(now)).toList();
    final past = appointments.where((a) => !a.scheduledAt.isAfter(now)).toList().reversed.toList();

    return Scaffold(
      appBar: LargeTitleAppBar(
        title: 'Appointments',
        showBack: false,
        actions: [
          IconButton(
            onPressed: () => context.push(RoutePaths.patientQueueNumber),
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'Queue status',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookAppointmentPage()),
            ),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: appointments.isEmpty
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
                if (upcoming.isNotEmpty) ...[
                  Text('Upcoming', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  for (final a in upcoming) ...[
                    _AppointmentTile(appointment: a),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 12),
                ],
                if (past.isNotEmpty) ...[
                  Text('Past', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                  const SizedBox(height: 10),
                  for (final a in past) ...[
                    _AppointmentTile(appointment: a),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
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
