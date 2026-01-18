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
  bool _isInitialized = false;

  // AudioContext that does NOT request audio focus, allowing sounds to mix
  static final AudioContext _noFocusContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  FeedbackService._();

  /// Initialize the audio pool. Call this at app startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _clickPool = await AudioPool.create(
        source: AssetSource('sounds/click.mp3'),
        minPlayers: 2,
        maxPlayers: 5,
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

  /// Feedback for selection changes (pickers, sliders).
  void selectionChange() {
    if (!LocalSettingsService.instance.feedbackEnabled.value) return;
    HapticFeedback.selectionClick();
    // No audio for selection changes - too frequent
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

  void dispose() {
    _clickPool?.dispose();
    _clickPool = null;
    _isInitialized = false;
  }
}
