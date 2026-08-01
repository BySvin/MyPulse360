import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? context.colors.patientAccent;
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
