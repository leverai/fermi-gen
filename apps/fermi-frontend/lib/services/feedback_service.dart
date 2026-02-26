import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';

/// Centralized service for UI feedback (haptics + audio).
///
/// Provides simple methods for different interaction types:
/// - [lightTap]: Subtle feedback for minor interactions
/// - [buttonPress]: Standard feedback for button presses
/// - [selectionChange]: Feedback for selection changes (pickers, toggles)
///
/// All methods respect [LocalSettingsService.feedbackEnabled].
class FeedbackService {
  static FeedbackService? _instance;
  static FeedbackService get instance => _instance ??= FeedbackService._();

  AudioPool? _clickPool;
  AudioPool? _secondaryClickPool;
  AudioPool? _successPool;
  AudioPool? _failPool;
  bool _isInitialized = false;

  // AudioContext that does NOT request audio focus, allowing sounds to mix
  static final AudioContext _noFocusContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  FeedbackService._();

  /// Initialize the audio pools. Call this at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _clickPool = await AudioPool.create(
        source: AssetSource('sounds/click.mp3'),
        minPlayers: 1,
        maxPlayers: 2,
        audioContext: _noFocusContext,
      );
      _secondaryClickPool = await AudioPool.create(
        source: AssetSource('sounds/click_secondary.mp3'),
        minPlayers: 1,
        maxPlayers: 2,
        audioContext: _noFocusContext,
      );
      _successPool = await AudioPool.create(
        source: AssetSource('sounds/success.mp3'),
        minPlayers: 1,
        maxPlayers: 1,
        audioContext: _noFocusContext,
      );
      _failPool = await AudioPool.create(
        source: AssetSource('sounds/fail.mp3'),
        minPlayers: 1,
        maxPlayers: 1,
        audioContext: _noFocusContext,
      );
      _isInitialized = true;
      debugPrint('FeedbackService: Initialized');
    } catch (e) {
      debugPrint('FeedbackService: Error initializing: $e');
    }
  }

  /// Light feedback for subtle interactions (toggles, minor taps).
  void lightTap() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    HapticFeedback.lightImpact();
    _playClick();
  }

  /// Standard feedback for button presses.
  void buttonPress() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    HapticFeedback.mediumImpact();
    _playClick();
  }

  /// Secondary click feedback for minor UI interactions (chips, checkboxes, etc).
  void secondaryClick() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    HapticFeedback.lightImpact();
    _playSecondaryClick();
  }

  /// Feedback for selection changes (pickers, sliders).
  void selectionChange() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    HapticFeedback.selectionClick();
    // No audio for selection changes - too frequent
  }

  /// Play success sound (e.g., survival mode pass).
  void playSuccess() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    if (_successPool == null) {
      debugPrint('FeedbackService: Success pool not initialized');
      return;
    }
    try {
      _successPool!.start();
    } catch (e) {
      debugPrint('FeedbackService: Error playing success: $e');
    }
  }

  /// Play fail sound (e.g., survival mode fail).
  void playFail() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    if (_failPool == null) {
      debugPrint('FeedbackService: Fail pool not initialized');
      return;
    }
    try {
      _failPool!.start();
    } catch (e) {
      debugPrint('FeedbackService: Error playing fail: $e');
    }
  }

  void _playClick() {
    if (_clickPool == null) {
      debugPrint('FeedbackService: Click pool not initialized');
      return;
    }

    try {
      _clickPool!.start();
    } catch (e) {
      debugPrint('FeedbackService: Error playing click: $e');
    }
  }

  void _playSecondaryClick() {
    if (_secondaryClickPool == null) {
      debugPrint('FeedbackService: Secondary click pool not initialized');
      return;
    }

    try {
      _secondaryClickPool!.start();
    } catch (e) {
      debugPrint('FeedbackService: Error playing secondary click: $e');
    }
  }

  void dispose() {
    _clickPool?.dispose();
    _clickPool = null;
    _secondaryClickPool?.dispose();
    _secondaryClickPool = null;
    _successPool?.dispose();
    _successPool = null;
    _failPool?.dispose();
    _failPool = null;
    _isInitialized = false;
  }
}
