// test/flutter_test_config.dart
// Configuration for Flutter tests, especially golden tests
// This file loads app fonts for golden tests (CRITICAL for CIs)

import 'dart:async';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts(); // Loads fonts from pubspec.yaml
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // Default configuration
      // Customize as needed for your project
    ),
  );
}
