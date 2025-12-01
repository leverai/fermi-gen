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
  int? selectedCategoryIndex;
  String? selectedDifficulty;
  bool isLocked = false;
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
  String? get currentCategoryBackendName {
    final categories = _configDto?.categories;
    if (categories == null ||
        categories.isEmpty ||
        selectedCategoryIndex == null) {
      return null;
    }
    final int i = selectedCategoryIndex!.clamp(0, categories.length - 1);
    return categories[i].name;
  }

  String? get currentCategorySlug {
    final categories = _configDto?.categories;
    if (categories == null ||
        categories.isEmpty ||
        selectedCategoryIndex == null) {
      return null;
    }
    final int i = selectedCategoryIndex!.clamp(0, categories.length - 1);
    return categories[i].slug;
  }

  int get resolvedPercentile {
    final stats = _playerStatsDto;
    final categoryKey = currentCategoryBackendName;
    final difficulty = selectedDifficulty;
    if (stats == null) return 0;
    if (categoryKey == null) {
      if (difficulty != null) {
        for (final e in stats.playerQuantiles.byDifficulty) {
          if (e.difficulty.toLowerCase() == difficulty.toLowerCase()) {
            final val = e.avgQuantile ?? e.avgPercentile;
            if (val != null) return val.round().clamp(0, 100);
          }
        }
        return 0;
      }
      final num? ov = stats.playerQuantiles.overall;
      if (ov != null) return ov.round().clamp(0, 100);
      return 0;
    }
    // categoryKey is guaranteed non-null here
    if (difficulty != null) {
      for (final e in stats.playerQuantiles.byCategoryAndDifficulty) {
        if (e.category == categoryKey &&
            e.difficulty.toLowerCase() == difficulty.toLowerCase()) {
          final val = e.avgQuantile ?? e.avgPercentile;
          if (val != null) return val.round().clamp(0, 100);
        }
      }
      // Difficulty selected but no entry found → show 0
      return 0;
    }
    // categoryKey is non-null, difficulty is null
    for (final e in stats.playerQuantiles.byCategory) {
      if (e.category == categoryKey) {
        final val = e.avgQuantile ?? e.avgPercentile;
        if (val != null) return val.round().clamp(0, 100);
      }
    }
    // No stats for the selected scope → show 0 instead of overall
    return 0;
  }

  // Lifecycle
  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final GameConfig config = await api.getGameConfigTyped();
      PlayerStatsResponse? stats;
      if (auth.firebaseUid != null) {
        stats = await api.getPlayerStatsTyped(playerId: auth.firebaseUid!);
      }
      _configDto = config;
      _playerStatsDto = stats;
      // Restore last round settings if available
      final LastRoundSettings? lrs = auth.lastRoundSettings;
      if (lrs != null) {
        isLocked = lrs.isPrivate;
        selectedDifficulty = lrs.difficulty;
        final categories = _configDto?.categories ?? const <CategoryInfo>[];
        final int idx = categories.indexWhere((c) => c.name == lrs.category);
        if (idx >= 0) {
          selectedCategoryIndex = idx;
        }
      }
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
  /// Skips refresh if data was refreshed less than 30 seconds ago.
  Future<void> refreshInBackground() async {
    // Debounce: skip if we refreshed recently
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
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
        stats = await api.getPlayerStatsTyped(playerId: auth.firebaseUid!);
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
  void toggleLock() {
    isLocked = !isLocked;
    notifyListeners();
  }

  void selectDifficulty(String? value) {
    selectedDifficulty = value;
    notifyListeners();
  }

  void selectCategoryIndex(int? index) {
    selectedCategoryIndex = index;
    notifyListeners();
  }

  Future<String> createGame({int? nQuestions}) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final String gameId = await api.createGame(
        isPrivate: isLocked,
        category: currentCategoryBackendName,
        difficulty: selectedDifficulty,
        nQuestions: nQuestions ?? 6,
      );
      // Persist last round settings so we can restore on return
      auth.lastRoundSettings = LastRoundSettings(
        category: currentCategoryBackendName,
        difficulty: selectedDifficulty,
        isPrivate: isLocked,
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

  Future<String> joinRandomGame({int? nQuestions}) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      debugPrint(
          '🔍 MainScreenController.joinRandomGame: firebaseUid=${auth.firebaseUid}, category=$currentCategoryBackendName, difficulty=$selectedDifficulty, nQuestions=${nQuestions ?? 6}');
      final String gameId = await api.joinRandomGame(
        category: currentCategoryBackendName,
        difficulty: selectedDifficulty,
        nQuestions: nQuestions ?? 6,
      );
      debugPrint(
          '🔍 MainScreenController.joinRandomGame: Received gameId=$gameId');
      // Persist last round settings (public round)
      auth.lastRoundSettings = LastRoundSettings(
        category: currentCategoryBackendName,
        difficulty: selectedDifficulty,
        isPrivate: false,
      );
      return gameId;
    } catch (e, st) {
      errorMessage = e.toString();
      print('❌ MainScreenController.joinRandomGame error: $e');
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
