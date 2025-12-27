import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/models/answer_value.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('AnswerAccuracyScale', () {
    testWidgets(
        'should render correctly with hidden answer text box by default',
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

      // The text box should be hidden by default (opacity 0)
      final opacityWidget = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AnswerAccuracyScale),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('should show answer text box during drag',
        (WidgetTester tester) async {
      // Arrange
      const currentAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');

      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: currentAnswer,
          editable: true,
          onAnswerChanged: (_) {},
        ),
      );

      // Act: Start drag
      final scaleFinder = find.byType(AnswerAccuracyScale);
      final center = tester.getCenter(scaleFinder);
      final gesture = await tester.startGesture(center);

      // Move significantly to exceed touch slop
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump(); // Handle move
      await tester.pump(); // Handle build after setState

      // Assert: Text box should be visible (opacity 1.0)
      final opacityWidget = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AnswerAccuracyScale),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacityWidget.opacity, 1.0);

      // Act: End drag
      await gesture.up();
      await tester.pump(); // Handle up
      await tester.pump(); // Handle build after setState

      // Assert: Opacity should be back to 0.0
      final opacityWidgetAfter = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AnswerAccuracyScale),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacityWidgetAfter.opacity, 0.0);
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

    testWidgets('should show scientific notation for out of bounds answer',
        (WidgetTester tester) async {
      // Arrange
      const currentAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');
      const revealedAnswer = AnswerValue(
        number: 1,
        orderOfMagnitude: '',
        unit: 'm',
        rawValue: 0.0005, // Out of bounds (< 1)
      );

      // Act
      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: currentAnswer,
          revealedAnswer: revealedAnswer,
          revealedColor: Colors.green,
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      // 0.0005 -> 5.00e-4
      expect(find.text('5.00e-4'), findsOneWidget);
    });
  });
}
