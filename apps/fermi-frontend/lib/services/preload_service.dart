import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';

/// Service that preloads game config and player stats in the background.
///
/// This allows screens to display data immediately without waiting for API calls.
/// The service caches the data and ensures only one preload operation runs at a time.
class PreloadService {
  final ApiService api;
  final AuthService auth;

  GameConfig? _cachedConfig;
  PlayerStatsResponse? _cachedStats;
  Future<void>? _preloadFuture;

  PreloadService({
    required this.api,
    required this.auth,
  });

  /// Gets the cached config, or null if not yet loaded.
  GameConfig? get cachedConfig => _cachedConfig;

  /// Gets the cached stats, or null if not yet loaded.
  PlayerStatsResponse? get cachedStats => _cachedStats;

  /// Starts preloading config and stats in the background.
  ///
  /// This method is idempotent - calling it multiple times will return
  /// the same future if a preload is already in progress.
  Future<void> preload() async {
    _preloadFuture ??= _doPreload();
    return _preloadFuture;
  }

  Future<void> _doPreload() async {
    try {
      // Ensure we have an access token before making API calls
      if (auth.accessToken == null) {
        // Wait a bit for auth to complete if it's still in progress
        await Future.delayed(const Duration(milliseconds: 100));
        if (auth.accessToken == null) {
          debugPrint(
              'PreloadService: No access token available, skipping preload');
          return;
        }
      }

      // Fetch config (required for main screen)
      _cachedConfig = await api.getGameConfigTyped();

      // Fetch stats if we have a user ID
      if (auth.firebaseUid != null) {
        _cachedStats = await api.getPlayerStatsTyped(
          playerId: auth.firebaseUid!,
        );
      }
    } catch (e) {
      debugPrint('PreloadService: Preload failed: $e');
      // Don't throw - allow screens to fetch data themselves if preload fails
    }
  }

  /// Clears the cached data.
  ///
  /// Useful when user signs out or when you want to force a refresh.
  void clearCache() {
    _cachedConfig = null;
    _cachedStats = null;
    _preloadFuture = null;
  }

  /// Forces a new preload, even if one is already in progress.
  ///
  /// This clears the cache and starts a fresh preload.
  Future<void> refresh() async {
    clearCache();
    return preload();
  }
}
