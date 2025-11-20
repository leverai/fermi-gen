import 'package:flutter/material.dart';

/// Centralized layout and sizing constants used across question-related UI.
/// Keeping these here avoids drift and enables consistent tuning.
@immutable
class LayoutConstants {
  const LayoutConstants._();

  // Spacing around primary sections
  static const double outerHorizontalPadding = 8.0;

  static const double spaceAfterQuestion = 10.0;
  static const double progressHeight = 6.0;
  static const double spaceAfterProgress = 10.0;
  static const double reservedFeedbackHeight = 50.0; // keeps layout stable
  static const double spaceBeforeAnswerOm = 10.0;

  // Question area sizing
  static const double minQuestionHeight = 100.0;

  // AnswerOm sizing rules
  static const double answerOmMinHeightClamp = 120.0;
  static const double answerOmSmallHeight = 150.0; // for small screens (<680)
  static const double answerOmMediumFraction = 0.20; // for medium heights
  static const double answerOmMediumClampMin = 170.0;
  static const double answerOmMediumClampMax = 190.0;
  static const double answerOmLargeFraction = 0.24; // for tall screens
  static const double answerOmLargeClampMin = 200.0;
  static const double answerOmLargeClampMax = 220.0;

  // AnswerOm gesture tolerance multiplier relative to its height
  static const double answerOmGestureToleranceFactor = 0.44;
}
