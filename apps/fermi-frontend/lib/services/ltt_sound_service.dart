import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';
import 'package:fermi_frontend/models/ltt_sound_profile.dart';

/// Manages sound effects for the LiveTypingText (LTT) widget.
///
/// Uses a small fixed set of shared [AudioPlayer] instances (round-robin)
/// instead of AudioPool-per-file to stay well within Android's ~32 concurrent
/// MediaPlayer limit. Asset paths are discovered per profile and played on
/// the next available shared player.
class LttSoundService {
  static final LttSoundService _instance = LttSoundService._internal();
  static LttSoundService get instance => _instance;

  LttSoundService._internal();

  /// Number of shared AudioPlayer instances for round-robin playback.
  static const int _playerCount = 3;

  /// Shared players used across all profiles.
  final List<AudioPlayer> _players = [];

  /// Index for round-robin player selection.
  int _nextPlayerIndex = 0;

  /// Whether the shared players have been created.
  bool _playersInitialized = false;

  /// Maps a profile name to its list of discovered asset source paths.
  final Map<String, List<String>> _profileAssets = {};

  /// Keeps track of initialization status per profile.
  final Map<String, bool> _initializedProfiles = {};

  /// Base path where LTT sound profiles live.
  static const String _basePath = 'assets/sounds/ltt';

  final Random _random = Random();

  // AudioContext that does NOT request audio focus, allowing sounds to mix
  // without interrupting background music or each other.
  static final AudioContext _noFocusContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Lazily create the shared players on first use.
  Future<void> _ensurePlayers() async {
    if (_playersInitialized) return;

    for (int i = 0; i < _playerCount; i++) {
      final player = AudioPlayer();
      await player.setAudioContext(_noFocusContext);
      _players.add(player);
    }
    _playersInitialized = true;
  }

  /// Discovers audio asset paths for [profile] and caches them.
  ///
  /// Call before typing starts to avoid first-stroke lag.
  Future<void> initializeProfile(LttSoundProfile profile) async {
    final profileName = profile.pathName;
    if (_initializedProfiles[profileName] == true) return;

    await _ensurePlayers();

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestJson);

      final profilePath = '$_basePath/$profileName/';

      final List<String> assetPaths = manifestMap.keys
          .where((key) => key.startsWith(profilePath) && key.endsWith('.mp3'))
          .map((key) {
        // AssetSource expects paths without the leading 'assets/' prefix.
        String sourcePath = key;
        if (sourcePath.startsWith('assets/')) {
          sourcePath = sourcePath.substring(7);
        }
        return sourcePath;
      }).toList();

      if (assetPaths.isEmpty) {
        debugPrint(
            'LttSoundService: No audio files found for profile: $profileName');
        _initializedProfiles[profileName] = true;
        return;
      }

      _profileAssets[profileName] = assetPaths;
      _initializedProfiles[profileName] = true;
      debugPrint(
          'LttSoundService: Initialized profile "$profileName" with ${assetPaths.length} variants.');
    } catch (e) {
      debugPrint(
          'LttSoundService: Error initializing profile $profileName: $e');
    }
  }

  /// Plays a random keystroke sound from the specified profile.
  Future<void> playKeystroke(LttSoundProfile profile,
      {bool force = false}) async {
    final profileName = profile.pathName;

    if (!force && !LocalSettingsService.instance.feedbackEnabled.value) return;

    if (_initializedProfiles[profileName] != true) {
      await initializeProfile(profile);
    }

    final assets = _profileAssets[profileName];
    if (assets == null || assets.isEmpty) return;

    try {
      final assetPath = assets[_random.nextInt(assets.length)];
      final player = _players[_nextPlayerIndex];
      _nextPlayerIndex = (_nextPlayerIndex + 1) % _playerCount;

      // Stop any current playback on this player, then play the new sound.
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint(
          'LttSoundService: Error playing keystroke for $profileName: $e');
    }
  }

  /// Disposes all shared players and clears cached data.
  void disposeAll() {
    for (final player in _players) {
      player.dispose();
    }
    _players.clear();
    _playersInitialized = false;
    _nextPlayerIndex = 0;
    _profileAssets.clear();
    _initializedProfiles.clear();
  }
}
