import 'package:flutter/material.dart';

enum MetricType {
  weight,
  bloodPressure,
  bloodSugar,
  heartRate,
  temperature,
  steps,
  sleepHours,
  caloriesBurned,
  exerciseMinutes;

  String get label => switch (this) {
        MetricType.weight => 'Weight',
        MetricType.bloodPressure => 'Blood Pressure',
        MetricType.bloodSugar => 'Blood Sugar',
        MetricType.heartRate => 'Heart Rate',
        MetricType.temperature => 'Temperature',
        MetricType.steps => 'Steps',
        MetricType.sleepHours => 'Sleep',
        MetricType.caloriesBurned => 'Calories',
        MetricType.exerciseMinutes => 'Exercise',
      };

  String get unit => switch (this) {
        MetricType.weight => 'kg',
        MetricType.bloodPressure => 'mmHg',
        MetricType.bloodSugar => 'mg/dL',
        MetricType.heartRate => 'bpm',
        MetricType.temperature => '\u00B0C',
        MetricType.steps => 'steps',
        MetricType.sleepHours => 'h',
        MetricType.caloriesBurned => 'kcal',
        MetricType.exerciseMinutes => 'min',
      };

  IconData get icon => switch (this) {
        MetricType.weight => Icons.monitor_weight_outlined,
        MetricType.bloodPressure => Icons.favorite_border,
        MetricType.bloodSugar => Icons.water_drop_outlined,
        MetricType.heartRate => Icons.monitor_heart_outlined,
        MetricType.temperature => Icons.thermostat,
        MetricType.steps => Icons.directions_walk_rounded,
        MetricType.sleepHours => Icons.bedtime_outlined,
        MetricType.caloriesBurned => Icons.local_fire_department_outlined,
        MetricType.exerciseMinutes => Icons.fitness_center_outlined,
      };

  /// The four core clinical vitals a patient can log by hand — shown in
  /// the "Vital Signs" grid. The rest are fitness/activity metrics that
  /// realistically only ever come from a connected device, shown in their
  /// own "Activity & Fitness" section instead.
  bool get isCoreVital => switch (this) {
        MetricType.weight || MetricType.bloodPressure || MetricType.bloodSugar || MetricType.heartRate || MetricType.temperature => true,
        _ => false,
      };
}
