import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle local settings storage using SharedPreferences.
///
/// Stores user preferences that don't need to be synced to the backend,
/// such as sound settings.
class LocalSettingsService {
  // Singleton instance
  static final LocalSettingsService _instance =
      LocalSettingsService._internal();
  static LocalSettingsService get instance => _instance;

  // Keys
  static const String _keyFeedbackEnabled = 'feedback_enabled';
  static const String _keyThemeMode = 'theme_mode';

  // State
  late final SharedPreferences _prefs;
  final ValueNotifier<bool> feedbackEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  bool _isInitialized = false;

  LocalSettingsService._internal();

  /// Initialize the service and load saved preferences.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Load values
      feedbackEnabled.value = _prefs.getBool(_keyFeedbackEnabled) ?? true;

      final String? savedThemeMode = _prefs.getString(_keyThemeMode);
      if (savedThemeMode != null) {
        themeMode.value = ThemeMode.values.firstWhere(
          (e) => e.name == savedThemeMode,
          orElse: () => ThemeMode.system,
        );
      }

      _isInitialized = true;
      debugPrint(
          'LocalSettingsService: Initialized. Feedback enabled: ${feedbackEnabled.value}, Theme: ${themeMode.value}');
    } catch (e) {
      debugPrint('LocalSettingsService: Error initializing: $e');
      // Fallback to default values if initialization fails
      feedbackEnabled.value = true;
      themeMode.value = ThemeMode.system;
    }
  }

  /// Toggle feedback setting and save to disk.
  Future<void> setFeedbackEnabled(bool enabled) async {
    if (!_isInitialized) await initialize();

    feedbackEnabled.value = enabled;
    await _prefs.setBool(_keyFeedbackEnabled, enabled);
    debugPrint('LocalSettingsService: Feedback set to $enabled');
  }

  /// Set theme mode and save to disk.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (!_isInitialized) await initialize();

    themeMode.value = mode;
    await _prefs.setString(_keyThemeMode, mode.name);
    debugPrint('LocalSettingsService: Theme set to $mode');
  }
}
