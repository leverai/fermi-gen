// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/services/firestore_game_realtime.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';

/// Controller for MainScreen: owns side-effects and derived state.
class MainScreenController extends ChangeNotifier {
  MainScreenController({required this.api, required this.auth});

  final ApiService api;
  final AuthService auth;

  // DTO-backed state
  GameConfig? _configDto;
  PlayerStatsResponse? _playerStatsDto;

  // UI state
  Set<int> selectedCategoryIndices = {};
  String? selectedDifficulty;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;
  DateTime? _lastRefreshTime;

  // Public accessors
  GameConfig? get configDto => _configDto;
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
    PlayerStatsResponse? preloadedStats,
  }) async {
    print(
        '[MainScreenController] initialize called. preloadedConfig=${preloadedConfig != null}, preloadedStats=${preloadedStats != null}');
    // If we have preloaded data, use it immediately
    if (preloadedConfig != null) {
      _configDto = preloadedConfig;
      _playerStatsDto = preloadedStats;
      isLoading = false;
      errorMessage = null;

      // Restore last round settings if available
      final LastRoundSettings? lrs = auth.lastRoundSettings;
      if (lrs != null) {
        selectedDifficulty = lrs.difficulty;
        // Restore categories from saved list
        if (lrs.categories != null) {
          final categories = _configDto?.categories ?? const <CategoryInfo>[];
          selectedCategoryIndices = lrs.categories!
              .map((name) => categories.indexWhere((c) => c.name == name))
              .where((idx) => idx >= 0)
              .toSet();
        }
      }

      notifyListeners();

      // Fetch fresh data in background to ensure we have the latest
      refreshInBackground();
      return;
    }

    // Otherwise, fetch as usual (existing code)
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      print('[MainScreenController] Fetching game config...');
      final GameConfig config = await api.getGameConfigTyped();
      print('[MainScreenController] Got config, fetching stats...');
      PlayerStatsResponse? stats;
      if (auth.firebaseUid != null) {
        stats = await api.getPlayerStatsTyped();
        print('[MainScreenController] Got stats');
      }
      _configDto = config;
      _playerStatsDto = stats;
      // Restore last round settings if available
      final LastRoundSettings? lrs = auth.lastRoundSettings;
      if (lrs != null) {
        selectedDifficulty = lrs.difficulty;
        // Restore categories from saved list
        if (lrs.categories != null) {
          final categories = _configDto?.categories ?? const <CategoryInfo>[];
          selectedCategoryIndices = lrs.categories!
              .map((name) => categories.indexWhere((c) => c.name == name))
              .where((idx) => idx >= 0)
              .toSet();
        }
      }
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

  /// Refreshes data in the background without blocking the UI.
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
      // Fetch data without setting isLoading to true
      // This allows the UI to remain responsive
      final GameConfig config = await api.getGameConfigTyped();
      PlayerStatsResponse? stats;
      if (auth.firebaseUid != null) {
        stats = await api.getPlayerStatsTyped();
      }

      // Update data
      _configDto = config;
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

  // Actions
  void selectDifficulty(String? value) {
    selectedDifficulty = value;
    notifyListeners();
  }

  void selectCategoryIndices(Set<int> indices) {
    selectedCategoryIndices = indices;
    notifyListeners();
  }

  Future<String> createGame({int? nQuestions}) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final String gameId = await api.createGame(
        categories: currentCategoryBackendNames,
        difficulty: selectedDifficulty,
        nQuestions: nQuestions ?? 6,
      );
      // Persist last round settings so we can restore on return
      auth.lastRoundSettings = LastRoundSettings(
        categories: currentCategoryBackendNames,
        difficulty: selectedDifficulty,
      );
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
