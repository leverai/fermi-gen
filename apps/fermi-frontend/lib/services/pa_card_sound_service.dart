import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';

/// Manages sound effects for PA (Percentile Achievement) cards.
///
/// Architecture:
/// - Uses AudioPool for better resource management with frequently-played sounds
/// - Respects global sound settings via [LocalSettingsService.feedbackEnabled]
/// - Supports different sounds for different achievement tiers
///
/// Create a new instance for each PA card display.
class PACardSoundService {
  AudioPool? _topPool;
  AudioPool? _applausePool;
  AudioPool? _bottomPool;
  bool _isInitialized = false;

  // AudioContext that does NOT request audio focus, allowing sounds to mix
  static final AudioContext _noFocusContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Initialize audio pools. Call this before playing sounds.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create pools with no audio focus - won't interrupt other audio
      // AudioPool is specifically designed for short, frequently-played sounds
      _topPool = await AudioPool.create(
        source: AssetSource('sounds/top.mp3'),
        minPlayers: 1,
        maxPlayers: 3,
        audioContext: _noFocusContext,
      );

      _applausePool = await AudioPool.create(
        source: AssetSource('sounds/small_applause.mp3'),
        minPlayers: 1,
        maxPlayers: 3,
        audioContext: _noFocusContext,
      );

      _bottomPool = await AudioPool.create(
        source: AssetSource('sounds/bottom.mp3'),
        minPlayers: 1,
        maxPlayers: 3,
        audioContext: _noFocusContext,
      );

      _isInitialized = true;
      debugPrint('PACardSoundService: Initialized');
    } catch (e) {
      debugPrint('PACardSoundService: Error initializing: $e');
    }
  }

  /// Play sound for top 5% or top 10% achievements.
  Future<void> playTop() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!LocalSettingsService.instance.feedbackEnabled.value) {
      debugPrint('PACardSoundService: Feedback disabled, skipping top sound');
      return;
    }

    try {
      debugPrint('PACardSoundService: Playing top.mp3');
      await _topPool?.start();
    } catch (e) {
      debugPrint('PACardSoundService: Error playing top sound: $e');
    }
  }

  /// Play sound for top 1% achievement (plays top sound + applause).
  Future<void> playTop1() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!LocalSettingsService.instance.feedbackEnabled.value) {
      debugPrint('PACardSoundService: Feedback disabled, skipping top1 sound');
      return;
    }

    try {
      debugPrint('PACardSoundService: Playing top.mp3 + small_applause.mp3');
      // Play both sounds simultaneously
      await Future.wait([
        _topPool?.start() ?? Future.value(),
        _applausePool?.start() ?? Future.value(),
      ]);
    } catch (e) {
      debugPrint('PACardSoundService: Error playing top1 sounds: $e');
    }
  }

  /// Play sound for bottom achievements (1%, 5%, or 10%).
  Future<void> playBottom() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!LocalSettingsService.instance.feedbackEnabled.value) {
      debugPrint(
          'PACardSoundService: Feedback disabled, skipping bottom sound');
      return;
    }

    try {
      debugPrint('PACardSoundService: Playing bottom.mp3');
      await _bottomPool?.start();
    } catch (e) {
      debugPrint('PACardSoundService: Error playing bottom sound: $e');
    }
  }

  /// Release resources.
  void dispose() {
    _topPool?.dispose();
    _topPool = null;

    _applausePool?.dispose();
    _applausePool = null;

    _bottomPool?.dispose();
    _bottomPool = null;

    _isInitialized = false;
  }
}
