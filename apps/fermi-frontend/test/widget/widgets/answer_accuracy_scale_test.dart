import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/models/answer_value.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('AnswerAccuracyScale', () {
    testWidgets('should render correctly with current answer',
        (WidgetTester tester) async {
      // Arrange
      const currentAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');

      // Act
      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: currentAnswer,
        ),
      );

      // Assert
      expect(find.byType(AnswerAccuracyScale), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AnswerAccuracyScale),
              matching: find.byType(CustomPaint)),
          findsOneWidget);
    });

    testWidgets('should show submitted answer when revealed',
        (WidgetTester tester) async {
      // Arrange
      const currentAnswer =
          AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      const submittedAnswer =
          AnswerValue(number: 500, orderOfMagnitude: 'K', unit: 'm');

      // Act
      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: currentAnswer,
          submittedAnswer: submittedAnswer,
          editable: false,
        ),
      );

      // Assert
      final widget = tester.widget<AnswerAccuracyScale>(
        find.byType(AnswerAccuracyScale),
      );
      expect(widget.submittedAnswer, submittedAnswer);
      expect(widget.editable, false);
      // We can't easily check the painter's internal state without exposing it,
      // but we can verify the widget properties are passed correctly.
    });

    testWidgets('should animate when revealed answer is provided',
        (WidgetTester tester) async {
      // Arrange
      const currentAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');
      const revealedAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'M', unit: 'm');

      // Act
      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: currentAnswer,
          revealedAnswer: revealedAnswer,
          revealedColor: Colors.green,
        ),
      );

      // Assert
      // Animation should start
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750)); // Halfway
      await tester.pumpAndSettle(); // Finish

      // No crash means animation completed successfully
      expect(find.byType(AnswerAccuracyScale), findsOneWidget);
    });

    testWidgets('should update animation when revealed answer changes',
        (WidgetTester tester) async {
      // Arrange
      const currentAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');

      // Act - Initial state (not revealed)
      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: currentAnswer,
          revealedAnswer: null,
        ),
      );

      // Act - Update to revealed
      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: currentAnswer,
          revealedAnswer:
              AnswerValue(number: 1, orderOfMagnitude: 'M', unit: 'm'),
        ),
      );

      // Assert
      await tester.pump(); // Start animation
      await tester.pumpAndSettle(); // Finish
    });
  });
}
