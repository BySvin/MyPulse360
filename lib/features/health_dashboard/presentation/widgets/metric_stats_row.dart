import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';

class MetricStat {
  const MetricStat(this.label, this.value);

  final String label;
  final String value;
}

class MetricStatsRow extends StatelessWidget {
  const MetricStatsRow({super.key, required this.stats});

  final List<MetricStat> stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i != 0) SizedBox(width: 1, height: 32, child: ColoredBox(color: colors.border)),
          Expanded(
            child: Column(
              children: [
                Text(stats[i].value, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(stats[i].label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
