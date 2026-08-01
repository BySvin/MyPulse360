import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';

class DispenseActionBar extends StatelessWidget {
  const DispenseActionBar({
    super.key,
    required this.enabled,
    required this.onDispense,
    this.loading = false,
  });

  final bool enabled;
  final VoidCallback onDispense;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: PrimaryButton(
          label: enabled ? 'Dispense' : 'Complete checklist to dispense',
          onPressed: enabled ? onDispense : null,
          loading: loading,
          color: colors.clinicianAccent,
        ),
      ),
    );
  }
}
