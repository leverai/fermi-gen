import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/logger.dart';

/// Minimal controller for answer reveal animations.
///
/// This controller manages the reveal animation timing and callbacks.
/// The actual visual animations in the new system are handled by:
/// - [AnswerAccuracyScale] - animates the correct answer indicator
/// - [UnitTapeController] - fades out tap/scroll indicators
///
/// The controller's primary role is to:
/// 1. Coordinate animation timing (600ms reveal duration)
/// 2. Update display state via [onProgress] callback
/// 3. Notify completion via [onComplete] callback
class AnswerController {
  /// Jump to a specific answer value instantly (no animation).
  /// In the new system, this is a no-op since display is props-driven.
  void jumpTo(AnswerValue target) {
    // No-op: Display is now controlled via props in QuestionAnswerCard
    AppLogger.debug('AnswerController.jumpTo: target=$target (no-op)');
  }

  /// Animate to a specific answer value.
  /// In the new system, this is a no-op since display is props-driven.
  Future<void> animateTo(AnswerValue target, Duration duration) async {
    // No-op: Display is now controlled via props in QuestionAnswerCard
    AppLogger.debug(
        'AnswerController.animateTo: target=$target, duration=${duration.inMilliseconds}ms (no-op)');
  }

  /// Trigger reveal animation with score-based color.
  ///
  /// This schedules [onProgress] and [onComplete] callbacks to fire at
  /// appropriate times, simulating a 600ms reveal animation.
  /// The actual visual animation is handled by [AnswerAccuracyScale].
  Future<void> reveal(
    AnswerValue start,
    AnswerValue target,
    Duration duration,
    Color color, {
    void Function(AnswerValue)? onProgress,
    void Function()? onComplete,
  }) async {
    AppLogger.debug(
        'AnswerController.reveal: start=$start, target=$target, duration=${duration.inMilliseconds}ms, color=$color');

    // Schedule completion callback after animation duration
    // The AnswerAccuracyScale handles the visual animation itself
    await Future.delayed(duration);

    // Report final progress value
    if (onProgress != null) {
      AppLogger.debug('AnswerController.reveal: calling onProgress');
      onProgress(target);
    }

    // Report completion
    if (onComplete != null) {
      AppLogger.debug('AnswerController.reveal: calling onComplete');
      onComplete();
    }

    AppLogger.debug('AnswerController.reveal: COMPLETE');
  }

  /// Reset visual state (clear reveal colors and reset tap indicators).
  /// In the new system, this is a no-op since state is props-driven.
  void resetVisualState() {
    // No-op: Display state is now controlled via props
    AppLogger.debug('AnswerController.resetVisualState (no-op)');
  }

  /// Close any open bottom sheets (legacy OM or Unit selectors).
  /// In the new system, unit selector is managed by [UnitTapeController].
  void closeBottomSheets() {
    // No-op: Unit selector managed separately via UnitTapeController
    AppLogger.debug('AnswerController.closeBottomSheets (no-op)');
  }

  /// Request focus on digit input (legacy).
  /// In the new system, input is via the scale slider.
  void requestFocus() {
    // No-op: No digit input in new system
    AppLogger.debug('AnswerController.requestFocus (no-op)');
  }
}
