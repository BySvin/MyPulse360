import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import 'primary_button.dart';

/// P10 — reusable error state pattern.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 40, color: colors.danger),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            PrimaryButton(label: 'Try again', onPressed: onRetry, fullWidth: false),
          ],
        ],
      ),
    );
  }
}
