import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Singleton service for Unity Ads integration.
///
/// Handles initialization, loading, and showing rewarded video ads.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // Unity Ads Game IDs
  static const String _androidGameId = '6031846';
  static const String _iosGameId = '6031847';

  // Placement IDs
  static const String _androidPlacementId = 'Rewarded_Android';
  static const String _iosPlacementId = 'Rewarded_iOS';

  bool _isInitialized = false;
  bool _isAdLoaded = false;
  bool _isAdShowing = false;

  /// Whether an ad is currently loaded and ready to show.
  bool get isAdLoaded => _isAdLoaded;

  /// Whether the SDK has been initialized.
  bool get isInitialized => _isInitialized;

  /// Get the current platform's placement ID.
  String get _placementId =>
      Platform.isAndroid ? _androidPlacementId : _iosPlacementId;

  /// Initialize the Unity Ads SDK.
  ///
  /// Should be called early in app lifecycle (e.g., after Firebase init).
  /// Uses test mode in debug builds.
  Future<void> init() async {
    if (_isInitialized) return;

    final gameId = Platform.isAndroid ? _androidGameId : _iosGameId;
    const testMode = kDebugMode;

    await UnityAds.init(
      gameId: gameId,
      testMode: testMode,
      onComplete: () {
        _isInitialized = true;
        debugPrint('AdService: Unity Ads initialized (testMode: $testMode)');
        // Pre-load an ad after initialization
        loadRewardedAd();
      },
      onFailed: (error, message) {
        debugPrint('AdService: Unity Ads init failed: $error - $message');
        _isInitialized = false;
      },
    );
  }

  /// Pre-load a rewarded ad.
  ///
  /// Call this before showing the ad to minimize wait time.
  void loadRewardedAd() {
    if (!_isInitialized) {
      debugPrint('AdService: Cannot load ad - SDK not initialized');
      return;
    }

    _isAdLoaded = false;

    UnityAds.load(
      placementId: _placementId,
      onComplete: (placementId) {
        debugPrint('AdService: Ad loaded for $placementId');
        _isAdLoaded = true;
      },
      onFailed: (placementId, error, message) {
        debugPrint(
            'AdService: Ad load failed for $placementId: $error - $message');
        _isAdLoaded = false;
      },
    );
  }

  /// Show a rewarded video ad.
  ///
  /// [onComplete] is called when the user watches the entire ad.
  /// [onSkipped] is called if the user skips the ad.
  /// [onFailed] is called if the ad fails to show.
  ///
  /// Returns false if the ad is not ready or already showing.
  bool showRewardedAd({
    required VoidCallback onComplete,
    VoidCallback? onSkipped,
    VoidCallback? onFailed,
  }) {
    if (!_isAdLoaded || _isAdShowing) {
      debugPrint(
          'AdService: Cannot show ad - loaded: $_isAdLoaded, showing: $_isAdShowing');
      onFailed?.call();
      return false;
    }

    _isAdShowing = true;

    UnityAds.showVideoAd(
      placementId: _placementId,
      onStart: (placementId) {
        debugPrint('AdService: Ad started for $placementId');
      },
      onClick: (placementId) {
        debugPrint('AdService: Ad clicked for $placementId');
      },
      onSkipped: (placementId) {
        debugPrint('AdService: Ad skipped for $placementId');
        _isAdShowing = false;
        _isAdLoaded = false;
        onSkipped?.call();
        // Reload for next time
        loadRewardedAd();
      },
      onComplete: (placementId) {
        debugPrint('AdService: Ad completed for $placementId');
        _isAdShowing = false;
        _isAdLoaded = false;
        onComplete();
        // Reload for next time
        loadRewardedAd();
      },
      onFailed: (placementId, error, message) {
        debugPrint('AdService: Ad failed for $placementId: $error - $message');
        _isAdShowing = false;
        _isAdLoaded = false;
        onFailed?.call();
        // Try to reload
        loadRewardedAd();
      },
    );

    return true;
  }
}
