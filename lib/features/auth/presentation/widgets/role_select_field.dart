import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../domain/entities/user_role.dart';

class RoleSelectField extends StatelessWidget {
  const RoleSelectField({super.key, required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('I am a...', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final role in UserRole.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(role),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == role ? colors.patientAccent : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: value == role ? colors.patientAccent : colors.border),
                    ),
                    child: Text(
                      role.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == role ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (role != UserRole.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}
