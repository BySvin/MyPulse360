import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../data/health_tips_data.dart';
import '../widgets/health_tip_card.dart';

/// Full list of curated wellness tips — replaces the old Health Overview
/// tile on the patient home screen.
class HealthTipsPage extends StatelessWidget {
  const HealthTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Health Tips'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final tip in kHealthTips) ...[
            HealthTipCard(tip: tip),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
