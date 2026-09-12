import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/empty_state_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../doctor/presentation/providers/doctor_providers.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';

/// Live-feeling queue tracker: position, estimated wait, and progress for
/// the patient's appointment today. Minutes-per-patient is a simple
/// heuristic (no real check-in system behind this mock backend), and the
/// screen re-evaluates on a timer so the wait estimate keeps ticking down.
class QueueStatusView extends ConsumerStatefulWidget {
  const QueueStatusView({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  static const int _minutesPerPatient = 15;

  @override
  ConsumerState<QueueStatusView> createState() => _QueueStatusViewState();
}

class _QueueStatusViewState extends ConsumerState<QueueStatusView> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.id));

    return AsyncSection(
        value: appointmentsAsync,
        data: (appointments) {
          final todaysMatches = appointments.where(
            (a) =>
                a.scheduledAt.year == now.year &&
                a.scheduledAt.month == now.month &&
                a.scheduledAt.day == now.day &&
                a.status != AppointmentStatus.cancelled,
          );

          if (todaysMatches.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyStateView(
                title: 'No visit today',
                message:
                    "You'll see your live queue number here once you have an appointment today.",
                icon: Icons.confirmation_number_outlined,
              ),
            );
          }

          final appointment = todaysMatches.first;
          final doctor = ref
              .watch(userProfileProvider(appointment.doctorId))
              .valueOrNull;
          final queueAsync = ref.watch(
            todaysQueueProvider(appointment.doctorId),
          );

          return AsyncSection(
            value: queueAsync,
            data: (queue) {
              final position = queue.indexWhere((a) => a.id == appointment.id);
              final peopleAhead = position < 0 ? 0 : position;
              final isDone = appointment.status == AppointmentStatus.completed;
              final isNow =
                  !isDone &&
                  peopleAhead == 0 &&
                  appointment.status == AppointmentStatus.inProgress;
              final etaMinutes =
                  peopleAhead * QueueStatusView._minutesPerPatient;
              final total = queue.isEmpty ? 1 : queue.length;
              final progress = isDone
                  ? 1.0
                  : ((total - peopleAhead) / total).clamp(0.0, 1.0);

              final statusText = isDone
                  ? 'Your visit is complete'
                  : isNow
                  ? "You're being seen now"
                  : peopleAhead == 0
                  ? "You're up next"
                  : '$peopleAhead patient${peopleAhead == 1 ? '' : 's'} ahead of you';

              Widget card = Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.8,
                    colors: [
                      const Color(0xFFB15B17), // Vibrant Orange/Amber
                      const Color(0xFFB15B17).withValues(alpha: 0.4),
                      const Color(0xFF101015),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB15B17).withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'YOUR QUEUE NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    position < 0
                        ? const Text(
                            '#—',
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: Colors.white,
                            ),
                          )
                        : TweenAnimationBuilder<int>(
                            tween: IntTween(
                              begin: 0,
                              end: position + 1,
                            ),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              '#$value',
                              style: const TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    const SizedBox(height: 6),
                    Text(
                      'with Dr. ${doctor?.fullName.split(' ').last ?? ''}'
                          .trim(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) =>
                            LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.14,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                isDone
                                    ? colors.success
                                    : colors.patientAccent,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );

              if (widget.onTap != null) {
                card = GestureDetector(
                  onTap: widget.onTap,
                  child: card,
                );
              }

              final consultations = ref.watch(patientHistoryProvider(user.id));
              Consultation? currentConsultation;
              for (final c in consultations) {
                if (c.appointmentId == appointment.id) {
                  currentConsultation = c;
                  break;
                }
              }

              final temp = currentConsultation?.vitals.temperatureCelsius;
              Widget? tempCard;
              if (temp != null) {
                tempCard = Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 2.0,
                      colors: [
                        colors.danger,
                        colors.danger.withValues(alpha: 0.6),
                        const Color(0xFF101015),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: colors.danger.withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: -10,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'BODY TEMPERATURE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            temp.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '°C',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  card
                      .animate()
                      .fadeIn(duration: 320.ms)
                      .scale(
                        begin: const Offset(0.94, 0.94),
                        curve: Curves.easeOutBack,
                      ),
                  ?tempCard,
                  if (!widget.compact && !isDone) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 22,
                            color: colors.patientAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  etaMinutes <= 0
                                      ? 'Any moment now'
                                      : '~$etaMinutes min estimated wait',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Updates automatically as the queue moves',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!widget.compact) ...[
                    const SizedBox(height: 24),
                    Text(
                      "Today's Queue",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < queue.length; i++) ...[
                      _QueueRow(
                            appointment: queue[i],
                            position: i + 1,
                            isMe: queue[i].id == appointment.id,
                            doctorAccent: colors.clinicianAccent,
                          )
                          .animate()
                          .fadeIn(delay: (i * 50).ms, duration: 220.ms)
                          .slideX(begin: 0.06, end: 0, curve: Curves.easeOut),
                      if (i != queue.length - 1) const SizedBox(height: 8),
                    ],
                  ]
                ],
              );
            },
          );
        },
      );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.appointment,
    required this.position,
    required this.isMe,
    required this.doctorAccent,
  });

  final Appointment appointment;
  final int position;
  final bool isMe;
  final Color doctorAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDone = appointment.status == AppointmentStatus.completed;
    // Other patients are anonymized — no name, initials, or reason shown to
    // anyone but themselves; only "you" is identified on your own device.
    final label = isMe ? 'You' : 'Patient $position';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? colors.patientAccent.withValues(alpha: 0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: isMe
              ? colors.patientAccent.withValues(alpha: 0.4)
              : colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDone
                  ? colors.success.withValues(alpha: 0.15)
                  : colors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: isDone
                ? Icon(Icons.check_rounded, size: 16, color: colors.success)
                : Text(
                    '$position',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          if (isMe)
            AvatarWidget(name: 'You', size: 30, color: doctorAccent)
          else
            CircleAvatar(
              radius: 15,
              backgroundColor: colors.surfaceMuted,
              child: Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: colors.textTertiary,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                color: isMe ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
          if (isMe)
            Text(
              appointment.appointmentType,
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            )
          else
            Text(
              isDone ? 'Done' : 'Waiting',
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            ),
        ],
      ),
    );
  }
}
