import 'package:flutter/material.dart';

enum MetricType {
  weight,
  bloodPressure,
  bloodSugar,
  heartRate;

  String get label => switch (this) {
        MetricType.weight => 'Weight',
        MetricType.bloodPressure => 'Blood Pressure',
        MetricType.bloodSugar => 'Blood Sugar',
        MetricType.heartRate => 'Heart Rate',
      };

  String get unit => switch (this) {
        MetricType.weight => 'kg',
        MetricType.bloodPressure => 'mmHg',
        MetricType.bloodSugar => 'mg/dL',
        MetricType.heartRate => 'bpm',
      };

  IconData get icon => switch (this) {
        MetricType.weight => Icons.monitor_weight_outlined,
        MetricType.bloodPressure => Icons.favorite_border,
        MetricType.bloodSugar => Icons.water_drop_outlined,
        MetricType.heartRate => Icons.monitor_heart_outlined,
      };
}
