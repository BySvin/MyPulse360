import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';

class StickySubmitBar extends StatelessWidget {
  const StickySubmitBar({
    super.key,
    required this.label,
    required this.onSubmit,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onSubmit;
  final bool loading;
  final bool enabled;

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
          label: label,
          onPressed: enabled ? onSubmit : null,
          loading: loading,
          color: colors.clinicianAccent,
        ),
      ),
    );
  }
}
