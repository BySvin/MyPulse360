import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_theme.dart';

/// Renders a short piece of text that is still loading — a name, usually.
///
/// A skeleton bar rather than a spinner: at this size a spinner draws more
/// attention than the value deserves, and an empty string would make the
/// layout jump once the value lands.
class AsyncInlineText extends StatelessWidget {
  const AsyncInlineText({
    super.key,
    required this.value,
    required this.builder,
    this.width = 120,
    this.style,
  });

  final AsyncValue<String?> value;
  final Widget Function(String text) builder;
  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return value.when(
      data: (text) => builder(text ?? 'Unknown'),
      error: (_, _) => Text('Unavailable', style: style ?? TextStyle(color: colors.textTertiary)),
      loading: () => Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
