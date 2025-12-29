import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Manages sound effects for a single confetti celebration.
///
/// Architecture:
/// - Crowd cheering: Uses default MediaPlayer mode for the longer 9-second audio
/// - Pop sounds: Uses AudioPool for short, rapidly-firing SFX
///
/// Both are configured with proper AudioContext to allow simultaneous playback
/// without audio focus conflicts on Android.
///
/// Create a new instance for each confetti animation.
class ConfettiSoundService {
  AudioPlayer? _cheerPlayer;
  AudioPool? _popPool;
  bool _isInitialized = false;

  // AudioContext that does NOT request audio focus, allowing sounds to mix
  static final AudioContext _noFocusContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Initialize players and audio pool. Call this before startCheering().
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create pop sound pool with no audio focus - won't interrupt other audio
      // AudioPool is specifically designed for short, simultaneous sounds
      _popPool = await AudioPool.create(
        source: AssetSource('sounds/confetti_pop.mp3'),
        minPlayers: 3, // Pre-load 3 players for rapid firing
        maxPlayers: 10, // Allow up to 10 simultaneous pops
        audioContext: _noFocusContext,
      );

      // Create cheer player - also with no focus to allow mixing
      _cheerPlayer = AudioPlayer();
      await _cheerPlayer!.setAudioContext(_noFocusContext);

      _isInitialized = true;
      debugPrint('ConfettiSoundService: Initialized');
    } catch (e) {
      debugPrint('ConfettiSoundService: Error initializing: $e');
    }
  }

  /// Start playing the crowd cheering background sound.
  Future<void> startCheering() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('ConfettiSoundService: Playing crowd_cheering.mp3');
      await _cheerPlayer?.play(AssetSource('sounds/crowd_cheering.mp3'));
    } catch (e) {
      debugPrint('ConfettiSoundService: Error playing crowd cheering: $e');
    }
  }

  /// Play a single pop sound (call this for each confetti burst).
  Future<void> playPop() async {
    if (!_isInitialized || _popPool == null) {
      debugPrint('ConfettiSoundService: Pop pool not initialized');
      return;
    }

    try {
      // AudioPool.start() plays the sound and allows overlapping plays
      await _popPool!.start();
    } catch (e) {
      debugPrint('ConfettiSoundService: Error playing pop: $e');
    }
  }

  /// Stop all sounds and release resources.
  void stop() {
    _cheerPlayer?.stop();
    _cheerPlayer?.dispose();
    _cheerPlayer = null;

    _popPool?.dispose();
    _popPool = null;

    _isInitialized = false;
  }

  void dispose() {
    stop();
  }
}
