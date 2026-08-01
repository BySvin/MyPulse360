import 'package:flutter/material.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/utils/validators.dart';

class PasswordStrengthHint extends StatelessWidget {
  const PasswordStrengthHint({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final checks = <(String, bool)>[
      ('At least 8 characters', password.length >= 8),
      ('An uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
      ('A number', RegExp(r'[0-9]').hasMatch(password)),
    ];
    if (password.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final (label, ok) in checks)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.circle_outlined,
                  size: 13,
                  color: ok ? colors.success : colors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

bool passwordIsStrong(String password) => Validators.isStrongPassword(password);
