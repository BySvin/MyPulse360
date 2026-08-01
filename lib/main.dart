import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'config/constants/hive_boxes.dart';
import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(HiveBoxes.settings);
  runApp(const ProviderScope(child: MyPulse360App()));
}

class MyPulse360App extends ConsumerWidget {
  const MyPulse360App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'MyPulse360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
