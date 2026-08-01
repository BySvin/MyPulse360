import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
    this.onLight = false,
    this.imagePath,
  });

  final String name;
  final double size;
  final Color? color;
  final bool onLight;

  /// Optional asset path (e.g. `assets/images/avatars/sarah.png`) for a
  /// real profile picture. Falls back to initials when null, or when the
  /// asset fails to load.
  final String? imagePath;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? context.colors.patientAccent;
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      return ClipOval(
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsCircle(bg),
        ),
      );
    }
    return _initialsCircle(bg);
  }

  Widget _initialsCircle(Color bg) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: onLight ? bg.withValues(alpha: 0.15) : bg.withValues(alpha: 0.9),
      child: Text(
        _initials,
        style: TextStyle(
          color: onLight ? bg : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
