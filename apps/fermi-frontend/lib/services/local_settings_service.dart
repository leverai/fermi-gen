import 'package:flutter/foundation.dart';
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
  static const String _keySoundEnabled = 'sound_enabled';

  // State
  late final SharedPreferences _prefs;
  final ValueNotifier<bool> soundEnabled = ValueNotifier<bool>(true);

  bool _isInitialized = false;

  LocalSettingsService._internal();

  /// Initialize the service and load saved preferences.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Load values
      soundEnabled.value = _prefs.getBool(_keySoundEnabled) ?? true;

      _isInitialized = true;
      debugPrint(
          'LocalSettingsService: Initialized. Sound enabled: ${soundEnabled.value}');
    } catch (e) {
      debugPrint('LocalSettingsService: Error initializing: $e');
      // Fallback to default values if initialization fails
      soundEnabled.value = true;
    }
  }

  /// Toggle sound setting and save to disk.
  Future<void> setSoundEnabled(bool enabled) async {
    if (!_isInitialized) await initialize();

    soundEnabled.value = enabled;
    await _prefs.setBool(_keySoundEnabled, enabled);
    debugPrint('LocalSettingsService: Sound set to $enabled');
  }
}
