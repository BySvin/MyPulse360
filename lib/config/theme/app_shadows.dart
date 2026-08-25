import 'package:flutter/material.dart';

/// Elevation presets — tinted with the ink hue (#1B2A38) rather than neutral
/// black, so a card sits *on* the warm paper ground instead of hovering over
/// it. Two levels only: resting and lifted.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x141B2A38), blurRadius: 16, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0D1B2A38), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x241B2A38), blurRadius: 32, offset: Offset(0, 14)),
  ];

  static const List<BoxShadow> none = [];

  const AppShadows._();
}
