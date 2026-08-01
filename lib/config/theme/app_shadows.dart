import 'package:flutter/material.dart';

/// Elevation presets — warmed slightly (a hint of brown instead of pure
/// black) to sit naturally on the cream background.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x1A1A1410), blurRadius: 10, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x0D1A1410), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x261A1410), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> none = [];

  const AppShadows._();
}
