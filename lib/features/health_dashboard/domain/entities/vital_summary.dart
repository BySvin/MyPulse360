import 'package:equatable/equatable.dart';

import 'metric_type.dart';

enum TrendDirection { up, down, flat }

/// Rolled-up "latest reading + 7-point sparkline" view used by the
/// dashboard's vital-sign cards.
class VitalSummary extends Equatable {
  const VitalSummary({
    required this.type,
    required this.latestDisplayValue,
    required this.sparkline,
    required this.trend,
    required this.trendLabel,
    required this.isNormal,
    required this.lastUpdated,
  });

  final MetricType type;
  final String latestDisplayValue;
  final List<double> sparkline;
  final TrendDirection trend;
  final String trendLabel;
  final bool isNormal;
  final DateTime lastUpdated;

  @override
  List<Object?> get props => [type, latestDisplayValue, sparkline, trend, trendLabel, isNormal, lastUpdated];
}
