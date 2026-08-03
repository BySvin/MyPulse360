import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/status_badge.dart';
import '../../patient/domain/entities/patient_profile.dart';
import '../../patient/domain/entities/wellness_goal.dart';
import 'entities/metric_type.dart';
import 'entities/vital_summary.dart';

/// A short, rule-based dashboard callout derived from the patient's health
/// profile and goals — not a clinical recommendation, just a nudge.
class HealthInsight {
  const HealthInsight({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = StatusTone.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final StatusTone tone;
}

const _conditionTips = {
  'Diabetes': 'Keep monitoring your blood sugar and stay consistent with checkups.',
  'High Blood Pressure': 'Watch your sodium intake and keep tracking your blood pressure.',
  'Asthma': 'Keep your inhaler accessible and avoid known triggers.',
  'Heart Condition': 'Stay consistent with prescribed medications and follow-up visits.',
};

/// Generates a short list of dashboard insight cards from the patient's
/// profile, current wellness goals, and (if a health platform is
/// connected) synced device data. Pure and stateless — no I/O.
List<HealthInsight> buildHealthInsights(
  PatientProfile profile,
  List<WellnessGoal> goals, {
  List<VitalSummary> vitals = const [],
}) {
  final insights = <HealthInsight>[];

  switch (profile.bmiCategory) {
    case 'Underweight':
      insights.add(const HealthInsight(
        icon: Icons.trending_down_rounded,
        title: 'BMI: Underweight',
        message: 'Consider talking to your doctor about a nutrition plan to reach a healthy weight.',
        tone: StatusTone.warning,
      ));
    case 'Healthy weight':
      insights.add(HealthInsight(
        icon: Icons.check_circle_outline_rounded,
        title: 'BMI: Healthy range',
        message: 'Your BMI of ${profile.bmi.toStringAsFixed(1)} is in the healthy range — keep it up!',
        tone: StatusTone.success,
      ));
    case 'Overweight':
      insights.add(const HealthInsight(
        icon: Icons.trending_up_rounded,
        title: 'BMI: Overweight',
        message: 'A bit of extra activity or a wellness goal around diet could help move this toward a healthy range.',
        tone: StatusTone.warning,
      ));
    case 'Obese':
      insights.add(const HealthInsight(
        icon: Icons.priority_high_rounded,
        title: 'BMI: Obese range',
        message: 'Consider discussing a weight-management plan with your doctor.',
        tone: StatusTone.danger,
      ));
  }

  for (final condition in profile.chronicConditions) {
    final tip = _conditionTips[condition];
    if (tip != null) {
      insights.add(HealthInsight(icon: Icons.favorite_border_rounded, title: condition, message: tip));
    }
  }

  if (goals.isNotEmpty) {
    final onTrack =
        goals.where((g) => g.status == GoalStatus.onTrack || g.status == GoalStatus.excellent).length;
    insights.add(HealthInsight(
      icon: Icons.flag_outlined,
      title: 'Weekly goals',
      message: '$onTrack of ${goals.length} wellness goals on track this week.',
      tone: onTrack == goals.length ? StatusTone.success : StatusTone.info,
    ));
  }

  if (profile.dateOfBirth == null || profile.gender == null || profile.bloodType == null) {
    insights.add(const HealthInsight(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Complete your health profile',
      message: 'Add your date of birth, gender, or blood type from Profile for more personalized insights.',
      tone: StatusTone.neutral,
    ));
  }

  VitalSummary? steps;
  VitalSummary? sleep;
  for (final v in vitals) {
    if (v.type == MetricType.steps && v.sparkline.isNotEmpty) steps = v;
    if (v.type == MetricType.sleepHours && v.sparkline.isNotEmpty) sleep = v;
  }
  if (steps != null && !steps.isNormal) {
    insights.add(const HealthInsight(
      icon: Icons.directions_walk_rounded,
      title: 'Low daily steps',
      message: 'Your synced step count has been under 5,000 lately — a short daily walk can help.',
      tone: StatusTone.warning,
    ));
  }
  if (sleep != null && !sleep.isNormal) {
    insights.add(const HealthInsight(
      icon: Icons.bedtime_outlined,
      title: 'Low sleep',
      message: 'Synced sleep has been under 6.5 hours a night — aim for 7-9 hours.',
      tone: StatusTone.warning,
    ));
  }

  return insights.take(5).toList();
}
