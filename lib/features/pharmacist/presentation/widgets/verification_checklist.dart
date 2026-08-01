import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';

const kVerificationSteps = [
  'Patient identity confirmed',
  'Dosage and quantity verified',
  'Known allergies checked',
  'Drug interaction check clear',
];

/// Checklist that must be fully resolved before Dispense becomes reachable.
class VerificationChecklist extends StatelessWidget {
  const VerificationChecklist({super.key, required this.checked, required this.onChanged});

  final Set<int> checked;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      // ListTile paints its background/ink on the nearest Material — without
      // this, it silently looks for one above the decorated Container and
      // (in debug mode) asserts that the splash would be invisible.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < kVerificationSteps.length; i++) ...[
              CheckboxListTile(
                value: checked.contains(i),
                onChanged: (_) => onChanged(i),
                title: Text(kVerificationSteps[i], style: const TextStyle(fontSize: 13.5)),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                activeColor: colors.clinicianAccent,
              ),
              if (i != kVerificationSteps.length - 1) Divider(height: 1, indent: 16, color: colors.border),
            ],
          ],
        ),
      ),
    );
  }
}
