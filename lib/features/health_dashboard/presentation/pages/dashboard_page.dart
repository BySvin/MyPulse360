import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/presentation/pages/book_appointment_page.dart';
import '../../../appointments/presentation/pages/reschedule_page.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../health_tips/data/health_tips_data.dart';
import '../../../health_tips/presentation/pages/health_tips_page.dart';
import '../../../health_tips/presentation/widgets/health_tip_card.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../domain/health_insights.dart';
import '../providers/health_dashboard_providers.dart';
import '../widgets/health_snapshot_card.dart';
import '../widgets/next_appointment_banner.dart';
import '../widgets/wellness_goal_row.dart';
import '../widgets/wellness_insight_card.dart';

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
    final vitals = ref.watch(dashboardSummariesProvider(user.id));
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
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HeroActionCard(
                    emoji: '📅',
                    title: 'Book Appointment',
                    subtitle: 'Schedule your next visit',
                    background: AppColors.inkBlack,
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
                    background: colors.patientAccent,
                    onTap: () => context.go(RoutePaths.patientPrescriptions),
                  ),
                ),
              ],
            ),
            // The snapshot card and insight list both make claims derived
            // from the profile (and, for insights, goals). Neither may
            // render until the profile fetch has settled — a still-loading
            // profile is not "no profile", and rendering nothing/wrong
            // during that window is what finding 2 flagged.
            AsyncSection(
              value: profileAsync,
              data: (profile) {
                if (profile == null) return const SizedBox.shrink();
                final insights = buildHealthInsights(
                  profile,
                  goalsAsync.valueOrNull ?? [],
                  vitals: vitals,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    HealthSnapshotCard(profile: profile),
                    if (insights.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Wellness Insights',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          for (final insight in insights) ...[
                            WellnessInsightCard(insight: insight),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Health Tips',
              actionLabel: 'See all',
              onAction: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HealthTipsPage())),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kHealthTips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    HealthTipCard(tip: kHealthTips[i], width: 220),
              ),
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
            const SizedBox(height: 6),
            if (nextAppointment != null &&
                nextAppointment.scheduledAt.year == now.year &&
                nextAppointment.scheduledAt.month == now.month &&
                nextAppointment.scheduledAt.day == now.day) ...[
              GestureDetector(
                onTap: () => context.go(RoutePaths.patientQueue),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.info.withValues(alpha: 0.08),
                    border: Border.all(
                      color: colors.info.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 18,
                        color: colors.info,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You're checked in today — view your live queue number",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (nextAppointment != null) ...[
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
              const SizedBox(height: 20),
            ],
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
        height: 152,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
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
