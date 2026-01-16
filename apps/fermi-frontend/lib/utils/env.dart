// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

String resolveApiBaseUrlOrThrow() {
  const raw = String.fromEnvironment('API_BASE_URL');
  if (raw.isEmpty) {
    const errorMsg = '''
    ❌ CONFIGURATION ERROR: Missing API_BASE_URL

    The app requires API_BASE_URL to be set at build time.

    For local development:
      flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1

    For production builds:
      flutter build appbundle --dart-define=API_BASE_URL=https://your-api.com/api/v1

    If you're seeing this in a production build, the CI/CD configuration is missing the dart-define.
    ''';
    // Use print() instead of debugPrint() so it works in release builds
    print(errorMsg);
    throw StateError('Missing required dart-define: API_BASE_URL');
  }
  // On web, Platform.isAndroid is not available, so check kIsWeb first
  if (!kIsWeb && Platform.isAndroid) {
    return raw.replaceFirst('http://localhost', 'http://10.0.2.2');
  }
  return raw;
}
