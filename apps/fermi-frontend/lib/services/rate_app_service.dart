import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage in-app review prompts at "happy" events.
///
/// ## Usage
/// Call `maybePromptReview()` after any "happy event" to potentially show
/// the native review prompt. The service handles:
/// - Minimum session count before prompting (3 sessions)
/// - Cooldown period between prompts (30 days)
/// - Platform availability checks
///
/// ## Adding New Happy Events
/// To trigger review prompts at new happy events:
/// 1. Import `RateAppService`
/// 2. Call `RateAppService.instance.maybePromptReview()` after the event
///
/// Example:
/// ```dart
/// await RateAppService.instance.maybePromptReview();
/// ```
///
/// ## Currently Supported Happy Events
/// - Player wins a Party game (rank 1)
/// - Player gets a top-tier PA card (top1, top5, top10)
class RateAppService {
  // Singleton
  RateAppService._internal();
  static final RateAppService instance = RateAppService._internal();

  // Keys for SharedPreferences
  static const String _keyLastPromptTime = 'rta_last_prompt_time';
  static const String _keySessionCount = 'rta_session_count';

  // Configuration
  static const int _minSessionsBeforePrompt = 3;
  static const int _cooldownDays = 30;

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  int _sessionCount = 0;

  /// Initialize the service. Call once at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _sessionCount = _prefs.getInt(_keySessionCount) ?? 0;

    // Increment session count on initialization (app open)
    _sessionCount++;
    await _prefs.setInt(_keySessionCount, _sessionCount);

    _isInitialized = true;
    debugPrint('RateAppService: Initialized. Session count: $_sessionCount');
  }

  /// Check eligibility and potentially show the native review prompt.
  ///
  /// This method is safe to call liberally - it enforces:
  /// - Minimum 3 sessions before first prompt
  /// - 30-day cooldown between prompts
  /// - Platform availability (native API support)
  ///
  /// Returns true if the prompt was requested, false otherwise.
  /// Note: Even when returning true, the native API may not show the dialog
  /// due to platform-enforced quotas.
  Future<bool> maybePromptReview() async {
    if (!_isInitialized) {
      debugPrint('RateAppService: Not initialized, skipping prompt');
      return false;
    }

    // Check minimum session count
    if (_sessionCount < _minSessionsBeforePrompt) {
      debugPrint(
          'RateAppService: Session count $_sessionCount < $_minSessionsBeforePrompt, skipping');
      return false;
    }

    // Check cooldown period
    final int? lastPromptMillis = _prefs.getInt(_keyLastPromptTime);
    if (lastPromptMillis != null) {
      final DateTime lastPrompt =
          DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
      final Duration elapsed = DateTime.now().difference(lastPrompt);
      if (elapsed.inDays < _cooldownDays) {
        debugPrint(
            'RateAppService: Within cooldown (${elapsed.inDays}/$_cooldownDays days), skipping');
        return false;
      }
    }

    // Check platform availability
    final InAppReview inAppReview = InAppReview.instance;
    final bool isAvailable = await inAppReview.isAvailable();

    if (!isAvailable) {
      debugPrint(
          'RateAppService: In-app review not available on this platform');
      return false;
    }

    // Request review
    debugPrint('RateAppService: Requesting in-app review');
    await inAppReview.requestReview();

    // Record prompt time
    await _prefs.setInt(
        _keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);

    return true;
  }
}
