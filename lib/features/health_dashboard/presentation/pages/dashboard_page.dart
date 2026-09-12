import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../shared/utils/spring_curve.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/presentation/pages/book_appointment_page.dart';
import '../../../appointments/presentation/pages/reschedule_page.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../../appointments/presentation/widgets/queue_status_view.dart';
import '../widgets/next_appointment_banner.dart';
import '../widgets/wellness_goal_row.dart';

/// P4 — Patient Dashboard: two big hero actions (Book Appointment,
/// Prescriptions) up top, a Health Tips strip, then goals/next-appointment/
/// reminders. Health Overview is no longer featured here.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    // Read as AsyncValue, not `.valueOrNull` — this page makes claims
    // ("No goals yet", the insight cards) that must wait for a settled
    // value rather than collapsing a loading/errored fetch into "empty".
    final goalsAsync = ref.watch(wellnessGoalsProvider(user.id));
    final profileAsync = ref.watch(patientProfileProvider(user.id));
    final nextAppointment = ref
        .watch(nextUpcomingAppointmentProvider(user.id))
        .valueOrNull;
    final doctor = nextAppointment == null
        ? null
        : ref.watch(userProfileProvider(nextAppointment.doctorId)).valueOrNull;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    final firstName = user.fullName.split(' ').first;

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
                      Text(
                        '$greeting, $firstName',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatters.full(now),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.notifications_rounded,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                ),
              ].animate().fadeIn(duration: 600.ms, curve: AppleSpringCurve()).slideY(begin: 0.2),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HeroActionCard(
                    emoji: '📅',
                    title: 'Book\nAppointments',
                    subtitle: 'Schedule your next visit',
                    background: const Color(0xFF5B17B1), // Vibrant Purple
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookAppointmentPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroActionCard(
                    emoji: '💊',
                    title: 'Prescriptions',
                    subtitle: 'View your medications',
                    background: const Color(0xFF0F5B33), // Vibrant Green
                    onTap: () => context.go(RoutePaths.patientPrescriptions),
                  ),
                ),
              ].animate(interval: 50.ms).fadeIn(duration: 600.ms, curve: AppleSpringCurve()).slideY(begin: 0.1),
            ),
            AsyncSection(
              value: profileAsync,
              data: (profile) {
                if (profile == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    QueueStatusView(
                      compact: true,
                      onTap: () => context.go(RoutePaths.patientAppointments),
                    ),
                    if (nextAppointment != null) ...[
                      const SizedBox(height: 20),
                      NextAppointmentBanner(
                        appointment: nextAppointment,
                        doctorName: doctor?.fullName ?? 'Your doctor',
                        onViewDetails: () => context.push(
                          RoutePaths.appointmentDetail(nextAppointment.id),
                        ),
                        onReschedule: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReschedulePage(appointment: nextAppointment),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            SectionHeader(
              title: 'Your Goals This Week',
              // Hiding the shortcut while unsettled is a safe default (it
              // declines to act), unlike the "No goals yet" text below,
              // which would be a false claim if shown before goals load.
              actionLabel: (goalsAsync.valueOrNull?.isEmpty ?? true)
                  ? null
                  : 'See all',
            ),
            const SizedBox(height: 10),
            AsyncSection(
              value: goalsAsync,
              data: (goals) => goals.isEmpty
                  ? Text(
                      'No goals yet — add some from your profile.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  : Column(
                      children: [
                        for (final goal in goals) ...[
                          WellnessGoalRow(goal: goal),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            Text(
              'Today\'s Reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Medication reminders will appear here once you add prescriptions.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroActionCard extends StatelessWidget {
  const _HeroActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.8,
            colors: [
              background,
              background.withValues(alpha: 0.4),
              const Color(0xFF101015),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: background.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

