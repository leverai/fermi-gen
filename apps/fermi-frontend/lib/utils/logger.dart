import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logging utility for the application.
///
/// Follows Flutter best practices:
/// - Only logs in debug mode for debug/info/warning levels
/// - Suppresses debug/info/warning logs during test execution (when SUPPRESS_TEST_LOGS is set)
/// - Always logs errors (even in release mode and during tests)
/// - Provides structured logging with appropriate log levels
class AppLogger {
  /// Check if test logs should be suppressed
  /// Set via --dart-define=SUPPRESS_TEST_LOGS=true when running tests
  static bool get _suppressTestLogs {
    const suppressLogs =
        bool.fromEnvironment('SUPPRESS_TEST_LOGS', defaultValue: true);
    return suppressLogs;
  }

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0, // Don't show method stack trace
      errorMethodCount: 3, // Show stack trace for errors
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.debug : Level.warning,
  );

  /// Log debug messages (only in debug mode, suppressed during tests if SUPPRESS_TEST_LOGS is set)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode && !_suppressTestLogs) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log info messages (only in debug mode, suppressed during tests if SUPPRESS_TEST_LOGS is set)
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode && !_suppressTestLogs) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log warning messages (only in debug mode, suppressed during tests if SUPPRESS_TEST_LOGS is set)
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode && !_suppressTestLogs) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log error messages (always logged, even in release mode)
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal errors (always logged, even in release mode)
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}
