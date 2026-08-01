import 'dart:math';

import '../../config/constants/app_constants.dart';

final _random = Random();

/// Simulates network latency in mock datasources so loading states are
/// actually visible during manual verification instead of resolving
/// instantly.
Future<void> simulateLatency() {
  final ms =
      AppConstants.mockLatencyMinMs +
      _random.nextInt(
        AppConstants.mockLatencyMaxMs - AppConstants.mockLatencyMinMs,
      );
  return Future.delayed(Duration(milliseconds: ms));
}
