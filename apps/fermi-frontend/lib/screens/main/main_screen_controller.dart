// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/services/firestore_game_realtime.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/models/user_limits.dart';

/// Controller for MainScreen: owns side-effects and derived state.
class MainScreenController extends ChangeNotifier {
  MainScreenController({
    required this.api,
    required this.auth,
    LocalSettingsService? localSettings,
  }) : localSettings = localSettings ?? LocalSettingsService.instance;

  final ApiService api;
  final AuthService auth;
  final LocalSettingsService localSettings;

  // DTO-backed state
  GameConfig? _configDto;
  UserLimits? _userLimitsDto;
  PlayerStatsResponse? _playerStatsDto;

  // UI state
  Set<int> selectedCategoryIndices = {};
  String? selectedDifficulty;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;
  DateTime? _lastRefreshTime;

  /// Current smart-search query (null/empty = not searching).
  ///
  /// Mutually exclusive with [selectedCategoryIndices]: a non-empty query
  /// clears and disables the category chips (see [setSearchQuery]); selecting
  /// a chip clears the query (see [selectCategoryIndices]). Difficulty applies
  /// in both modes.
  String? searchQuery;

  /// The current user's recent smart-search queries (MRU order), loaded from
  /// [LocalSettingsService]. Rendered as tappable chips in the party sheet.
  List<String> recentSearches = const <String>[];

  /// Whether smart search is enabled server-side (from `/game/config`).
  /// While false the search box is hidden and the screen behaves as before.
  bool smartSearchEnabled = false;

  /// True when a non-empty search query is active (categories are disabled).
  bool get isSearching => (searchQuery?.trim().isNotEmpty ?? false);

  // Public accessors
  GameConfig? get configDto => _configDto;
  UserLimits? get userLimitsDto => _userLimitsDto;
  PlayerStatsResponse? get playerStatsDto => _playerStatsDto;
  List<DifficultyInfo> get difficulties =>
      _configDto?.difficulties ?? const <DifficultyInfo>[];

  // Derived/computed
  /// Returns list of selected category backend names, or null if none/all selected.
  List<String>? get currentCategoryBackendNames {
    final categories = _configDto?.categories;
    if (categories == null || categories.isEmpty) {
      return null;
    }
    // If none selected or all selected, return null (no filter)
    if (selectedCategoryIndices.isEmpty ||
        selectedCategoryIndices.length == categories.length) {
      return null;
    }
    return selectedCategoryIndices
        .map((i) => categories[i.clamp(0, categories.length - 1)].name)
        .toList();
  }

  /// Returns list of selected category slugs for display, or null if none/all selected.
  List<String>? get currentCategorySlugs {
    final categories = _configDto?.categories;
    if (categories == null || categories.isEmpty) {
      return null;
    }
    if (selectedCategoryIndices.isEmpty ||
        selectedCategoryIndices.length == categories.length) {
      return null;
    }
    return selectedCategoryIndices
        .map((i) => categories[i.clamp(0, categories.length - 1)].slug)
        .toList();
  }

  // Lifecycle
  Future<void> initialize({
    GameConfig? preloadedConfig,
    UserLimits? preloadedUserLimits,
    PlayerStatsResponse? preloadedStats,
  }) async {
    print(
        '[MainScreenController] initialize called. preloadedConfig=${preloadedConfig != null}, preloadedUserLimits=${preloadedUserLimits != null}, preloadedStats=${preloadedStats != null}');
    // If we have preloaded data, use it immediately
    if (preloadedConfig != null) {
      _configDto = preloadedConfig;
      _userLimitsDto = preloadedUserLimits;
      _playerStatsDto = preloadedStats;
      smartSearchEnabled = preloadedConfig.smartSearchEnabled;
      isLoading = false;
      errorMessage = null;

      _restoreLastRoundSettings();

      notifyListeners();

      // Load this user's recent searches (best-effort) for the party sheet.
      unawaited(loadRecentSearches());

      // Fetch fresh user limits and stats in background
      refreshInBackground();
      return;
    }

    // Otherwise, fetch as usual (existing code)
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      print('[MainScreenController] Fetching game config and user limits...');
      // Fetch config and user limits in parallel
      final results = await Future.wait([
        api.getGameConfigTyped(),
        api.getUserLimitsTyped(),
      ]);
      final GameConfig config = results[0] as GameConfig;
      final UserLimits userLimits = results[1] as UserLimits;

      print('[MainScreenController] Got config and limits, fetching stats...');
      PlayerStatsResponse? stats;
      if (auth.firebaseUid != null) {
        stats = await api.getPlayerStatsTyped();
        print('[MainScreenController] Got stats');
      }
      _configDto = config;
      _userLimitsDto = userLimits;
      _playerStatsDto = stats;
      smartSearchEnabled = config.smartSearchEnabled;
      _restoreLastRoundSettings();
      // Load this user's recent searches (best-effort) for the party sheet.
      unawaited(loadRecentSearches());
      print('[MainScreenController] initialize complete');
    } catch (e, st) {
      errorMessage = e.toString();
      print('❌ MainScreenController.initialize error: $e');
      print(st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Restores in-session last-round settings (categories, difficulty, and
  /// search query). When a search query was last used, it takes precedence
  /// over categories (the two are mutually exclusive).
  void _restoreLastRoundSettings() {
    final LastRoundSettings? lrs = auth.lastRoundSettings;
    if (lrs == null) return;
    selectedDifficulty = lrs.difficulty;
    final String? q = lrs.searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      searchQuery = lrs.searchQuery;
      selectedCategoryIndices = {};
      return;
    }
    if (lrs.categories != null) {
      final categories = _configDto?.categories ?? const <CategoryInfo>[];
      selectedCategoryIndices = lrs.categories!
          .map((name) => categories.indexWhere((c) => c.name == name))
          .where((idx) => idx >= 0)
          .toSet();
    }
  }

  /// Loads the current user's recent smart-search queries (best-effort) and
  /// notifies listeners. No-op without an authenticated user.
  Future<void> loadRecentSearches() async {
    final String? uid = auth.firebaseUid;
    if (uid == null || uid.isEmpty) {
      recentSearches = const <String>[];
      return;
    }
    try {
      recentSearches = await localSettings.getRecentSearches(uid);
      notifyListeners();
    } catch (e) {
      print('⚠️ MainScreenController.loadRecentSearches error: $e');
    }
  }

  /// Refreshes user limits and stats in the background without blocking the UI.
  /// Config is NOT refreshed since it's static and cached at startup.
  /// Skips refresh if data was refreshed less than 30 seconds ago,
  /// unless [force] is true.
  Future<void> refreshInBackground({bool force = false}) async {
    // Debounce: skip if we refreshed recently (unless forced)
    final now = DateTime.now();
    if (!force &&
        _lastRefreshTime != null &&
        now.difference(_lastRefreshTime!).inSeconds < 30) {
      debugPrint('MainScreenController: Skipping refresh (too soon)');
      return;
    }
    _lastRefreshTime = now;

    try {
      // Only fetch user limits and stats - config is static
      final UserLimits userLimits = await api.getUserLimitsTyped();
      PlayerStatsResponse? stats;
      if (auth.firebaseUid != null) {
        stats = await api.getPlayerStatsTyped();
      }

      // Update data
      _userLimitsDto = userLimits;
      _playerStatsDto = stats;

      // Notify listeners to update UI with fresh data
      notifyListeners();
    } catch (e, st) {
      // Log error but don't show error message to user
      // Keep showing cached data instead
      print('⚠️ MainScreenController.refreshInBackground error: $e');
      print(st);
    }
  }

  /// Refreshes only user limits. Call after actions that affect limits
  /// (e.g., creating a party game).
  Future<void> refreshUserLimits() async {
    try {
      final UserLimits userLimits = await api.getUserLimitsTyped();
      _userLimitsDto = userLimits;
      notifyListeners();
    } catch (e, st) {
      print('⚠️ MainScreenController.refreshUserLimits error: $e');
      print(st);
    }
  }

  // Actions
  void selectDifficulty(String? value) {
    // Difficulty applies in both search and category modes; leave the other
    // inputs untouched.
    selectedDifficulty = value;
    notifyListeners();
  }

  void selectCategoryIndices(Set<int> indices) {
    selectedCategoryIndices = indices;
    // Selecting a category clears any active search (mutually exclusive).
    if (indices.isNotEmpty && isSearching) {
      searchQuery = null;
    }
    notifyListeners();
  }

  /// Sets the smart-search query. A non-empty query clears and disables the
  /// category chips (mutually exclusive); clearing the query re-enables them.
  void setSearchQuery(String? value) {
    final String? trimmed = value?.trim();
    searchQuery = (trimmed == null || trimmed.isEmpty) ? null : value;
    if (isSearching && selectedCategoryIndices.isNotEmpty) {
      selectedCategoryIndices = {};
    }
    notifyListeners();
  }

  /// Clears the smart-search query.
  void clearSearchQuery() {
    if (searchQuery == null) return;
    searchQuery = null;
    notifyListeners();
  }

  Future<String> createGame({int? nQuestions}) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    final String? activeQuery = isSearching ? searchQuery!.trim() : null;
    try {
      final String gameId = await api.createGame(
        categories: currentCategoryBackendNames,
        difficulty: selectedDifficulty,
        nQuestions: nQuestions ?? 6,
        searchQuery: activeQuery,
      );
      // Persist last round settings so we can restore on return. This is also
      // the source of truth for the search query at start-success time (the
      // lobby reads it back via [saveSearchToRecents]).
      auth.lastRoundSettings = LastRoundSettings(
        categories: activeQuery != null ? null : currentCategoryBackendNames,
        difficulty: selectedDifficulty,
        searchQuery: activeQuery,
      );
      // NOTE: recents are NOT saved here. The search runs at GAME START (not at
      // create), so a query that matches too few questions still creates a
      // game successfully and only fails at start. Saving recents on create
      // would record queries that never produced a playable game. Recents are
      // instead saved on a successful START via [saveSearchToRecents].
      return gameId;
    } catch (e, st) {
      errorMessage = e.toString();
      print('❌ MainScreenController.createGame error: $e');
      print(st);
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /// Saves [query] to the current user's recent smart-search queries.
  ///
  /// Called after a smart-search game STARTS successfully (recents must reflect
  /// queries that actually produced a playable game — the search runs at start,
  /// not at create). Best-effort and keyed by firebase uid; a null/blank query
  /// or missing uid is a no-op. Refreshes [recentSearches] and notifies.
  Future<void> saveSearchToRecents(String? query) async {
    final String? trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final String? uid = auth.firebaseUid;
    if (uid == null || uid.isEmpty) return;
    try {
      await localSettings.addRecentSearch(uid, trimmed);
      recentSearches = await localSettings.getRecentSearches(uid);
      notifyListeners();
    } catch (e) {
      print('⚠️ MainScreenController.saveSearchToRecents error: $e');
    }
  }

  /// The smart-search query from the most recent create, or null. This is the
  /// query that will be run at game start; the lobby threads it back to
  /// [saveSearchToRecents] on a successful start.
  String? get lastSearchQuery => auth.lastRoundSettings?.searchQuery;

  /// Factory for realtime adapter used by downstream screens.
  GameRealtime buildRealtimeAdapter() {
    final String currentId =
        auth.firebaseUid ?? (fb.FirebaseAuth.instance.currentUser?.uid ?? '');
    return FirestoreGameRealtime(
      currentPlayerId: currentId,
      submit: (gid, index, answer) =>
          api.submitAnswer(gameId: gid, answer: answer),
      next: (gid) => api.nextQuestion(gameId: gid),
      upvote: (uid) => api.upvoteQuestion(questionUid: uid),
      deUpvote: (uid) => api.deUpvoteQuestion(questionUid: uid),
      downvote: (uid) => api.downvoteQuestion(questionUid: uid),
      deDownvote: (uid) => api.deDownvoteQuestion(questionUid: uid),
      resolveLocale: () => auth.locale,
      setLocale: (loc) => api.setUserLocale(locale: loc),
      gameConfig: _configDto, // Pass config for name→slug conversion
    );
  }
}
