import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/ltt_sound_service.dart';
import 'package:fermi_frontend/models/ltt_sound_profile.dart';

/// A widget that displays text character-by-character to simulate live typing.
///
/// It supports human-like variable typing speed, punctuation pauses, and
/// synchronized audio feedback via [LttSoundService].
class LiveTypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final LttSoundProfile? soundProfile;
  final TextAlign textAlign;
  final VoidCallback? onTypingComplete;
  final bool bypassFeedbackEnabled;

  const LiveTypingText({
    super.key,
    required this.text,
    this.style,
    this.soundProfile,
    this.textAlign = TextAlign.start,
    this.onTypingComplete,
    this.bypassFeedbackEnabled = false,
  });

  @override
  State<LiveTypingText> createState() => _LiveTypingTextState();
}

class _LiveTypingTextState extends State<LiveTypingText> {
  String _displayedText = '';
  int _currentIndex = 0;
  bool _isDisposed = false;
  final Random _random = Random();

  int _typingToken = 0;

  @override
  void initState() {
    super.initState();
    _initAndStart();
  }

  Future<void> _initAndStart() async {
    final token = ++_typingToken;
    await _preloadAudio();
    if (mounted && _typingToken == token) {
      _typeNextCharacter(token);
    }
  }

  @override
  void didUpdateWidget(covariant LiveTypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // If the text changes entirely, restart the typing animation
      _currentIndex = 0;
      _displayedText = '';
      _initAndStart();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _preloadAudio() async {
    if (widget.soundProfile != null) {
      await LttSoundService.instance.initializeProfile(widget.soundProfile!);
    }
  }

  Future<void> _typeNextCharacter(int token) async {
    if (_isDisposed || _typingToken != token) return;

    if (_currentIndex < widget.text.length) {
      final String nextChar = widget.text[_currentIndex];

      setState(() {
        _displayedText += nextChar;
      });

      // Play sound synchronously with the visual update
      if (widget.soundProfile != null) {
        // We do not await the sound, so it doesn't block UI progression
        LttSoundService.instance.playKeystroke(
          widget.soundProfile!,
          force: widget.bypassFeedbackEnabled,
        );
      }

      _currentIndex++;

      // Determine the delay before the next character
      final delayMs = _calculateDelay(
          nextChar,
          _currentIndex < widget.text.length
              ? widget.text[_currentIndex]
              : null);

      await Future.delayed(Duration(milliseconds: delayMs));

      // Continue loop
      _typeNextCharacter(token);
    } else {
      // Typing finished
      widget.onTypingComplete?.call();
    }
  }

  /// Calculates a human-like delay for the next keystroke based on the
  /// current character and some random jitter.
  int _calculateDelay(String currentChar, String? nextChar) {
    // Base speed: fast typing (approx 40ms per char)
    int baseDelay = 30 + _random.nextInt(25); // 30ms to 54ms

    // Add slight pauses for punctuation
    if (currentChar == '.' || currentChar == '!' || currentChar == '?') {
      baseDelay += 200 + _random.nextInt(150); // Pause for end of sentence
    } else if (currentChar == ',' || currentChar == ';' || currentChar == ':') {
      baseDelay += 100 + _random.nextInt(100); // Pause for clause breaks
    } else if (currentChar == ' ') {
      // Spacebar is usually quick, slightly more consistent
      baseDelay = 20 + _random.nextInt(20);
    }

    return baseDelay;
  }

  @override
  Widget build(BuildContext context) {
    // We use a Text widget that renders what has been "typed" so far.
    // If the widget is updated with new constraints, the text will wrap naturally.
    return Text(
      _displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
