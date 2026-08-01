import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

/// Text field with inline validation states (P2 sign-up shows one valid,
/// one error field mid-validation).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.isValid = false,
    this.onChanged,
    this.suffixIcon,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final bool isValid;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderColor = errorText != null
        ? colors.danger
        : isValid
            ? colors.success
            : colors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          autofillHints: autofillHints,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            suffixIcon: isValid && errorText == null
                ? Icon(Icons.check_circle, color: colors.success, size: 20)
                : suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: BorderSide(color: errorText != null ? colors.danger : colors.patientAccent, width: 1.5),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(errorText!, style: TextStyle(color: colors.danger, fontSize: 12)),
        ],
      ],
    );
  }
}
