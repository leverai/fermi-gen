import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Pumps a widget wrapped in a minimal MaterialApp with app theme extensions.
///
/// This helper provides a consistent test environment with the app's theme
/// configuration. Use this for widget tests that need theme context.
///
/// Example:
/// ```dart
/// await pumpWithMaterialApp(tester, const MyWidget());
/// ```
Future<void> pumpWithMaterialApp(
  WidgetTester tester,
  Widget child, {
  Locale? locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[
          AppTheme.defaultTheme(),
          const AppFont(),
        ],
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps a widget wrapped in MaterialApp with a Scaffold.
///
/// This is a convenience wrapper for widgets that need a Scaffold context.
///
/// Example:
/// ```dart
/// await pumpWithScaffold(tester, const MyScreen());
/// ```
Future<void> pumpWithScaffold(
  WidgetTester tester,
  Widget child, {
  Locale? locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[
          AppTheme.defaultTheme(),
          const AppFont(),
        ],
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps a widget and waits for all animations and async operations to settle.
///
/// This is a convenience wrapper around `pumpAndSettle()` that also wraps
/// the widget in MaterialApp with theme extensions.
///
/// Example:
/// ```dart
/// await pumpAndSettleWithMaterialApp(tester, const MyAnimatedWidget());
/// ```
Future<void> pumpAndSettleWithMaterialApp(
  WidgetTester tester,
  Widget child, {
  Locale? locale,
  Duration timeout = const Duration(seconds: 5),
}) async {
  await pumpWithMaterialApp(tester, child, locale: locale);
  await tester.pumpAndSettle(timeout);
}

/// Pumps a widget and waits for a specific duration.
///
/// Useful for testing animations or delayed state updates.
///
/// Example:
/// ```dart
/// await pumpWithDelay(tester, const MyWidget(), duration: Duration(seconds: 2));
/// ```
Future<void> pumpWithDelay(
  WidgetTester tester,
  Widget child, {
  required Duration duration,
  Locale? locale,
}) async {
  await pumpWithMaterialApp(tester, child, locale: locale);
  await tester.pump(duration);
}

/// Pumps until a finder matches, with optional timeout.
///
/// Useful for waiting on async operations that update the UI.
///
/// Example:
/// ```dart
/// await pumpUntil(
///   tester,
///   const MyWidget(),
///   find.text('Loaded'),
///   timeout: Duration(seconds: 5),
/// );
/// ```
Future<void> pumpUntil(
  WidgetTester tester,
  Widget child,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Locale? locale,
}) async {
  await pumpWithMaterialApp(tester, child, locale: locale);
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TimeoutException(
    'pumpUntil timed out after ${timeout.inSeconds} seconds',
    timeout,
  );
}
