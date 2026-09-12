import 'package:flutter/material.dart';

/// Elevation presets — tinted with the ink hue (#1B2A38) rather than neutral
/// black, so a card sits *on* the warm paper ground instead of hovering over
/// it. Two levels only: resting and lifted.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A1B2A38), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x051B2A38), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x141B2A38), blurRadius: 40, offset: Offset(0, 20)),
  ];

  static const List<BoxShadow> none = [];

  const AppShadows._();
}
