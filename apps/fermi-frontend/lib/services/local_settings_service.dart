import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fermi_frontend/models/ltt_sound_profile.dart';

/// Service to handle local settings storage using SharedPreferences.
///
/// Stores user preferences that don't need to be synced to the backend,
/// such as sound settings and owned sound profiles.
class LocalSettingsService {
  // Singleton instance
  static final LocalSettingsService _instance =
      LocalSettingsService._internal();
  static LocalSettingsService get instance => _instance;

  // Keys
  static const String _keyFeedbackEnabled = 'feedback_enabled';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keySelectedSoundProfile = 'selected_sound_profile';
  static const String _keyOwnedSoundProfiles = 'owned_sound_profiles';

  // State
  late final SharedPreferences _prefs;
  final ValueNotifier<bool> feedbackEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<LttSoundProfile?> selectedSoundProfile =
      ValueNotifier<LttSoundProfile?>(LttSoundProfile.ios);
  final ValueNotifier<Set<LttSoundProfile>> ownedSoundProfiles =
      ValueNotifier<Set<LttSoundProfile>>({});

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

      // Load selected sound profile
      final String? savedProfile = _prefs.getString(_keySelectedSoundProfile);
      if (savedProfile != null) {
        selectedSoundProfile.value = LttSoundProfile.values
            .where(
              (e) => e.pathName == savedProfile,
            )
            .firstOrNull;
      }

      // Load owned profiles; always include free profiles
      final Set<LttSoundProfile> owned =
          LttSoundProfile.values.where((p) => p.isFree).toSet();
      final List<String>? savedOwned =
          _prefs.getStringList(_keyOwnedSoundProfiles);
      if (savedOwned != null) {
        for (final name in savedOwned) {
          final match = LttSoundProfile.values
              .where(
                (e) => e.pathName == name,
              )
              .firstOrNull;
          if (match != null) owned.add(match);
        }
      }
      ownedSoundProfiles.value = owned;

      _isInitialized = true;
      debugPrint(
          'LocalSettingsService: Initialized. Feedback enabled: ${feedbackEnabled.value}, Theme: ${themeMode.value}');
    } catch (e) {
      debugPrint('LocalSettingsService: Error initializing: $e');
      // Fallback to default values if initialization fails
      feedbackEnabled.value = true;
      themeMode.value = ThemeMode.system;
      selectedSoundProfile.value = LttSoundProfile.ios;
      ownedSoundProfiles.value =
          LttSoundProfile.values.where((p) => p.isFree).toSet();
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

  /// Set the active sound profile (null = silent) and save to disk.
  Future<void> setSelectedSoundProfile(LttSoundProfile? profile) async {
    if (!_isInitialized) await initialize();

    selectedSoundProfile.value = profile;
    if (profile != null) {
      await _prefs.setString(_keySelectedSoundProfile, profile.pathName);
    } else {
      await _prefs.remove(_keySelectedSoundProfile);
    }
    debugPrint(
        'LocalSettingsService: Sound profile set to ${profile?.displayName ?? "Silent"}');
  }

  /// Add a purchased sound profile to the owned set and save to disk.
  Future<void> addOwnedSoundProfile(LttSoundProfile profile) async {
    if (!_isInitialized) await initialize();

    final updated = Set<LttSoundProfile>.from(ownedSoundProfiles.value)
      ..add(profile);
    ownedSoundProfiles.value = updated;
    await _prefs.setStringList(
      _keyOwnedSoundProfiles,
      updated.map((p) => p.pathName).toList(),
    );
    debugPrint('LocalSettingsService: Purchased ${profile.displayName}');
  }
}
