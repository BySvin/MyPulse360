import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

/// Shown to both doctors (during diagnosis) and pharmacists (before
/// dispensing) — allergy safety matters at both points in the visit.
class AllergyBanner extends StatelessWidget {
  const AllergyBanner({super.key, required this.allergies});

  final List<String> allergies;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (allergies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.08),
          border: Border.all(color: colors.success.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: colors.successText),
            const SizedBox(width: 8),
            Text('No known allergies', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.08),
        border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5, color: colors.textPrimary, height: 1.4),
                children: [
                  const TextSpan(text: 'Allergies: ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: allergies.join(', ')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
