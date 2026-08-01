import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/hive_boxes.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = Hive.box(HiveBoxes.settings);
    final stored = box.get(HiveBoxes.keyThemeMode) as String?;
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    final box = Hive.box(HiveBoxes.settings);
    box.put(HiveBoxes.keyThemeMode, mode.name);
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
