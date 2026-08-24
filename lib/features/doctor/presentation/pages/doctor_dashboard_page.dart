import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/presentation/widgets/sign_out_icon_button.dart';
import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/domain/entities/patient_profile.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../providers/doctor_providers.dart';
import '../widgets/patient_queue_tile.dart';

/// D1 — Doctor Dashboard, redrawn to match the desktop reference: header
/// banner, stat cards, a patient queue with a "Start Visit" CTA on the
/// active patient, and a real alerts panel. Doctor's scope stays limited
/// to patients / history / start visit — no extra sidebar sections.
class DoctorDashboardPage extends ConsumerWidget {
  const DoctorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final queueAsync = ref.watch(todaysQueueProvider(user.id));
    final isDesktop =
        MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: AsyncSection(
          value: queueAsync,
          data: (queue) {
            final confirmed = queue
                .where((a) => a.status == AppointmentStatus.confirmed)
                .length;
            final pending = queue
                .where((a) => a.status == AppointmentStatus.scheduled)
                .length;
            final completed = queue
                .where((a) => a.status == AppointmentStatus.completed)
                .length;
            final waitingLong = queue
                .where(
                  (a) =>
                      QueueStatus.forAppointment(a).label == 'Waiting 30+ min',
                )
                .toList();
            final activeIndex = queue.indexWhere(
              (a) => a.status != AppointmentStatus.completed,
            );
            final activeRoom = activeIndex >= 0
                ? queue[activeIndex].roomLabel
                : null;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _HeaderCard(
                  user: user,
                  room: activeRoom,
                  showSignOut: !isDesktop,
                ),
                const SizedBox(height: 16),
                _StatCardsRow(
                  patientsToday: queue.length,
                  confirmed: confirmed,
                  pending: pending,
                  completed: completed,
                ),
                const SizedBox(height: 22),
                Text(
                  'Patient queue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (queue.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyStateView(
                      title: 'No patients scheduled today',
                      message: 'Enjoy the quiet — your queue will appear here.',
                      icon: Icons.event_available_outlined,
                    ),
                  )
                else
                  for (var i = 0; i < queue.length; i++) ...[
                    _DoctorQueueRow(
                          appointment: queue[i],
                          isActive: i == activeIndex,
                        )
                        .animate()
                        .fadeIn(delay: (i * 50).ms, duration: 220.ms)
                        .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 10),
                  ],
                if (waitingLong.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Alerts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.08),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: colors.warningText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${waitingLong.length} patient${waitingLong.length == 1 ? '' : 's'} waiting 30+ minutes',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.user,
    required this.room,
    required this.showSignOut,
  });

  final AppUser user;
  final String? room;
  final bool showSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.clinicianAccent,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greetingWord()}, ${user.fullName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [DateFormatters.full(DateTime.now()), ?room].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          if (showSignOut) ...[
            const SizedBox(width: 6),
            const IconTheme(
              data: IconThemeData(color: Colors.white),
              child: SignOutIconButton(),
            ),
          ],
        ],
      ),
    );
  }

  String _greetingWord() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }
}

class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({
    required this.patientsToday,
    required this.confirmed,
    required this.pending,
    required this.completed,
  });

  final int patientsToday;
  final int confirmed;
  final int pending;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stats = [
      ('Patients today', patientsToday, colors.textPrimary),
      ('Confirmed', confirmed, colors.success),
      ('Pending', pending, colors.warningText),
      ('Completed', completed, colors.textSecondary),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        for (final (label, value, color) in stats)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: colors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DoctorQueueRow extends ConsumerWidget {
  const _DoctorQueueRow({required this.appointment, required this.isActive});

  final Appointment appointment;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final patient = ref
        .watch(userProfileProvider(appointment.patientId))
        .valueOrNull;
    final profileAsync = ref.watch(
      patientProfileProvider(appointment.patientId),
    );
    final PatientProfile? profile = profileAsync.valueOrNull;
    final name = patient?.fullName ?? 'Patient';
    final status = QueueStatus.forAppointment(appointment);
    final age = profile?.age;
    final genderInitial = (profile?.gender?.isNotEmpty ?? false)
        ? profile!.gender![0].toUpperCase()
        : '';
    final hasAllergies = profile != null && profile.allergies.isNotEmpty;
    // While the profile is still loading, a patient WITH allergies is
    // indistinguishable from one without — don't fall through to the status
    // tag in that window, since that reads as an (unverified) "no
    // allergies". Render neither tag until the profile settles.
    final profileSettled = !profileAsync.isLoading;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: isActive
              ? colors.clinicianAccent.withValues(alpha: 0.5)
              : colors.border,
        ),
      ),
      child: Row(
        children: [
          AvatarWidget(name: name, color: colors.clinicianAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  [
                    if (age != null) '$age$genderInitial',
                    appointment.appointmentType,
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (hasAllergies)
                      _Tag(label: 'Allergy', color: colors.danger)
                    else if (profileSettled && !isActive)
                      _Tag(
                        label: status.label,
                        color: _toneColor(colors, status.tone),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            PrimaryButton(
              label: 'Start Visit',
              fullWidth: false,
              color: colors.clinicianAccent,
              onPressed: () => context.push(
                RoutePaths.patientHistory(
                  appointment.patientId,
                  appointmentId: appointment.id,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => context.push(
                RoutePaths.patientHistory(
                  appointment.patientId,
                  appointmentId: appointment.id,
                ),
              ),
              child: const Text('View'),
            ),
        ],
      ),
    );
  }

  Color _toneColor(AppSemanticColors colors, StatusTone tone) => switch (tone) {
    StatusTone.success => colors.successText,
    StatusTone.warning => colors.warningText,
    StatusTone.danger => colors.danger,
    StatusTone.info => colors.infoText,
    StatusTone.neutral => colors.textSecondary,
  };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
