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
  static const String _keyOwnedAvatars = 'owned_avatars';

  /// Per-user smart-search recents are stored under `recent_searches_<uid>`.
  static const String _keyRecentSearchesPrefix = 'recent_searches_';

  /// Maximum number of recent searches retained per user (MRU eviction).
  static const int _maxRecentSearches = 10;

  // State
  // Not `final`: re-assignable so tests can reset the backing store via
  // [resetForTest] + [initialize] with fresh mock values.
  late SharedPreferences _prefs;
  final ValueNotifier<bool> feedbackEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<LttSoundProfile?> selectedSoundProfile =
      ValueNotifier<LttSoundProfile?>(LttSoundProfile.ios);
  final ValueNotifier<Set<LttSoundProfile>> ownedSoundProfiles =
      ValueNotifier<Set<LttSoundProfile>>({});
  final ValueNotifier<Set<String>> ownedAvatars =
      ValueNotifier<Set<String>>({});

  /// MRU-ordered recent smart-search queries for the most recently accessed
  /// user. Updated whenever [getRecentSearches] or [addRecentSearch] runs so
  /// widgets can rebuild their recent-search chips. Keyed by [_recentsUid].
  final ValueNotifier<List<String>> recentSearches =
      ValueNotifier<List<String>>(const <String>[]);

  /// The uid whose recents are currently reflected in [recentSearches.value].
  String? _recentsUid;

  bool _isInitialized = false;

  LocalSettingsService._internal();

  /// Resets in-memory initialization state so the next [initialize] re-reads
  /// from `SharedPreferences`. Test-only (the singleton otherwise latches its
  /// backing store for the process lifetime).
  @visibleForTesting
  void resetForTest() {
    _isInitialized = false;
    _recentsUid = null;
    recentSearches.value = const <String>[];
  }

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

      // Load owned avatars
      final List<String>? savedAvatars = _prefs.getStringList(_keyOwnedAvatars);
      if (savedAvatars != null) {
        ownedAvatars.value = savedAvatars.toSet();
      }

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

  /// Add a purchased avatar URL to the owned set and save to disk.
  Future<void> addOwnedAvatar(String url) async {
    if (!_isInitialized) await initialize();

    final updated = Set<String>.from(ownedAvatars.value)..add(url);
    ownedAvatars.value = updated;
    await _prefs.setStringList(_keyOwnedAvatars, updated.toList());
    debugPrint('LocalSettingsService: Purchased avatar: $url');
  }

  // --- Smart-search recents (per user) ---

  String _recentSearchesKey(String uid) => '$_keyRecentSearchesPrefix$uid';

  /// Returns the user's recent smart-search queries, most-recent first.
  ///
  /// Strings are returned exactly as stored (raw, trimmed, original casing).
  /// Also refreshes [recentSearches] so listeners reflect this user's list.
  Future<List<String>> getRecentSearches(String uid) async {
    if (!_isInitialized) await initialize();

    final List<String> stored =
        _prefs.getStringList(_recentSearchesKey(uid)) ?? const <String>[];
    _recentsUid = uid;
    recentSearches.value = List<String>.unmodifiable(stored);
    return List<String>.from(stored);
  }

  /// Adds [query] to the user's recent searches and persists the result.
  ///
  /// Semantics (see handoff §2 "Recents detail"):
  /// - The query is trimmed; empty/whitespace-only queries are ignored.
  /// - Stored as the raw trimmed string (original casing preserved).
  /// - Case-insensitive dedup: an existing entry equal ignoring case is
  ///   removed, then the new (trimmed, original-cased) value is inserted at
  ///   the front (MRU).
  /// - The list is capped at [_maxRecentSearches]; the least-recently-used
  ///   entries beyond the cap are evicted.
  Future<void> addRecentSearch(String uid, String query) async {
    if (!_isInitialized) await initialize();

    final String trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final List<String> current = List<String>.from(
        _prefs.getStringList(_recentSearchesKey(uid)) ?? const <String>[]);

    // Case-insensitive dedup: drop any existing entry equal ignoring case.
    final String lowered = trimmed.toLowerCase();
    current.removeWhere((e) => e.toLowerCase() == lowered);

    // Insert at front (MRU) and cap.
    current.insert(0, trimmed);
    final List<String> capped = current.length > _maxRecentSearches
        ? current.sublist(0, _maxRecentSearches)
        : current;

    await _prefs.setStringList(_recentSearchesKey(uid), capped);

    // Keep the notifier in sync if it currently reflects this user.
    if (_recentsUid == null || _recentsUid == uid) {
      _recentsUid = uid;
      recentSearches.value = List<String>.unmodifiable(capped);
    }
    debugPrint(
        'LocalSettingsService: Recent searches for $uid now ${capped.length}');
  }
}
