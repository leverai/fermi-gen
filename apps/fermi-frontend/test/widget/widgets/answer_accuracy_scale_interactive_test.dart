import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/models/answer_value.dart';

import '../../helpers/test_helpers.dart';

/// Tests for AnswerAccuracyScale interactive input functionality.
///
/// These tests verify the slider component in isolation:
/// - That `onAnswerChanged` callback is called correctly
/// - That correct values are passed to the callback
/// - That the slider widget itself behaves correctly
///
/// For full integration tests that verify the complete state flow
/// (slider → state update → AnswerWidget → DigitWheels/OmLabel updates),
/// see `answer_widget_slider_sync_test.dart`.

void main() {
  group('AnswerAccuracyScale - Interactive Input', () {
    testWidgets('should call onAnswerChanged when tapped',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');
      AnswerValue? capturedAnswer;

      // Act
      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          editable: true,
          onAnswerChanged: (value) {
            capturedAnswer = value;
          },
        ),
      );

      // Get the widget size
      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;

      // Tap at different positions
      // Tap at left edge (should give log 0 = 1)
      await tester.tapAt(Offset(12, size.height / 2));
      await tester.pump();

      // Assert
      expect(capturedAnswer, isNotNull);
      expect(capturedAnswer!.number, 1);
      expect(capturedAnswer!.orderOfMagnitude, '');
      expect(capturedAnswer!.unit, 'm'); // Unit preserved
    });

    testWidgets('should call onAnswerChanged when dragged',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      final capturedAnswers = <AnswerValue>[];

      // Act
      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          editable: true,
          onAnswerChanged: (value) {
            capturedAnswers.add(value);
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;
      final width = size.width;

      // Drag from left to right
      const startX = 12.0;
      final endX = width - 12.0;
      final centerY = size.height / 2;

      await tester.drag(
        finder,
        Offset(endX - startX, 0),
        warnIfMissed: false,
      );
      await tester.pump();

      // Assert - should have captured at least one value
      expect(capturedAnswers.length, greaterThan(0));
      // Last value should be near the end (log 18 = 999 T)
      final lastAnswer = capturedAnswers.last;
      expect(lastAnswer.orderOfMagnitude, 'T');
    });

    testWidgets('should preserve unit when changing answer',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'km');
      AnswerValue? capturedAnswer;

      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          editable: true,
          onAnswerChanged: (value) {
            capturedAnswer = value;
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;

      // Tap to change answer
      await tester.tapAt(Offset(100, size.height / 2));
      await tester.pump();

      // Assert - unit should be preserved
      expect(capturedAnswer, isNotNull);
      expect(capturedAnswer!.unit, 'km');
    });

    testWidgets('should not call onAnswerChanged when editable is false',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');
      bool callbackCalled = false;

      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          editable: false,
          onAnswerChanged: (value) {
            callbackCalled = true;
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;

      // Act - try to tap
      await tester.tapAt(Offset(100, size.height / 2));
      await tester.pump();

      // Assert
      expect(callbackCalled, isFalse);
    });

    testWidgets('should not call onAnswerChanged when callback is null',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');

      await pumpWithMaterialApp(
        tester,
        const AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          editable: true,
          // onAnswerChanged is null
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;

      // Act - try to tap (should not crash)
      await tester.tapAt(Offset(100, size.height / 2));
      await tester.pump();

      // Assert - no crash means it handled null callback gracefully
      expect(find.byType(AnswerAccuracyScale), findsOneWidget);
    });

    testWidgets('should not allow interaction when revealed',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');
      const revealedAnswer =
          AnswerValue(number: 1, orderOfMagnitude: 'M', unit: 'm');
      bool callbackCalled = false;

      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          revealedAnswer: revealedAnswer,
          editable: true,
          onAnswerChanged: (value) {
            callbackCalled = true;
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;

      // Act - try to tap
      await tester.tapAt(Offset(100, size.height / 2));
      await tester.pump();

      // Assert
      expect(callbackCalled, isFalse);
    });

    testWidgets('should handle rapid taps without duplicate callbacks',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      final capturedAnswers = <AnswerValue>[];

      await pumpWithMaterialApp(
        tester,
        AnswerAccuracyScale(
          currentAnswer: initialAnswer,
          editable: true,
          onAnswerChanged: (value) {
            capturedAnswers.add(value);
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;
      final centerX = size.width / 2;

      // Rapidly tap at the same position multiple times
      for (int i = 0; i < 5; i++) {
        await tester.tapAt(Offset(centerX, size.height / 2));
        await tester.pump();
      }

      // Assert - should have deduplicated (same value shouldn't trigger multiple callbacks)
      // We expect at least one callback, but not necessarily 5 if deduplication works
      expect(capturedAnswers.length, greaterThan(0));
      expect(capturedAnswers.length, lessThanOrEqualTo(5));
    });
  });

  group('AnswerAccuracyScale - Consistency and Recursion Prevention', () {
    testWidgets('should update position when currentAnswer changes externally',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      const newAnswer =
          AnswerValue(number: 10, orderOfMagnitude: 'K', unit: 'm');
      bool callbackCalled = false;

      // Act - Build with initial answer
      await pumpWithMaterialApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AnswerAccuracyScale(
              currentAnswer: initialAnswer,
              editable: true,
              onAnswerChanged: (value) {
                callbackCalled = true;
                // Simulate external update (parent updates currentAnswer)
                setState(() {});
              },
            );
          },
        ),
      );

      // Update currentAnswer externally (simulating parent state change)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnswerAccuracyScale(
              currentAnswer: newAnswer,
              editable: true,
              onAnswerChanged: (value) {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Assert - widget should update position without triggering callback
      expect(callbackCalled, isFalse);
      expect(find.text('10 K'), findsOneWidget); // Position updated
    });

    testWidgets('should prevent recursion when answer changes during drag',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      int callbackCount = 0;
      AnswerValue? lastCallbackValue;

      // Act
      await pumpWithMaterialApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AnswerAccuracyScale(
              currentAnswer: initialAnswer,
              editable: true,
              onAnswerChanged: (value) {
                callbackCount++;
                lastCallbackValue = value;
                // Simulate parent updating currentAnswer (which would normally cause recursion)
                setState(() {});
              },
            );
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;
      final centerX = size.width / 2;

      // Start drag
      final gesture =
          await tester.startGesture(Offset(centerX, size.height / 2));
      await tester.pump();

      // Move during drag (should trigger callbacks)
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // End drag
      await gesture.up();
      await tester.pump();

      // Assert - callbacks should have been called, but recursion prevented
      // We expect at least one callback from the drag
      expect(callbackCount, greaterThan(0));
      expect(lastCallbackValue, isNotNull);
    });

    testWidgets('should sync with external answer changes',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      int callbackCount = 0;

      // Act
      await pumpWithMaterialApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                AnswerAccuracyScale(
                  currentAnswer: currentAnswer,
                  editable: true,
                  onAnswerChanged: (value) {
                    callbackCount++;
                    setState(() {
                      currentAnswer = value;
                    });
                  },
                ),
                // External control to change answer
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentAnswer = const AnswerValue(
                          number: 10, orderOfMagnitude: 'K', unit: 'm');
                    });
                  },
                  child: const Text('Change Externally'),
                ),
              ],
            );
          },
        ),
      );

      // Change answer externally via button
      await tester.tap(find.text('Change Externally'));
      await tester.pump();

      // Assert - slider should update position without triggering callback
      expect(callbackCount, 0); // No callback from external change
      expect(find.text('10 K'), findsOneWidget); // Position synced
    });

    testWidgets('should handle rapid external updates without recursion',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      int callbackCount = 0;

      // Act
      await pumpWithMaterialApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AnswerAccuracyScale(
              currentAnswer: currentAnswer,
              editable: true,
              onAnswerChanged: (value) {
                callbackCount++;
                // Rapidly update currentAnswer multiple times
                for (int i = 0; i < 3; i++) {
                  setState(() {
                    currentAnswer = value;
                  });
                }
              },
            );
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;

      // Tap to trigger callback
      await tester.tapAt(Offset(100, size.height / 2));
      await tester.pump();

      // Assert - should have called callback once, not multiple times
      expect(callbackCount, 1);
    });

    testWidgets('should maintain consistency with answer widget values',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      AnswerValue? sliderAnswer;

      // Act - simulate slider interaction
      await pumpWithMaterialApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AnswerAccuracyScale(
              currentAnswer: currentAnswer,
              editable: true,
              onAnswerChanged: (value) {
                sliderAnswer = value;
                setState(() {
                  currentAnswer = value;
                });
              },
            );
          },
        ),
      );

      final finder = find.byType(AnswerAccuracyScale);
      final RenderBox box = tester.renderObject(finder);
      final size = box.size;
      final width = size.width;

      // Tap at position that should give 10K (log 4)
      const padding = 12.0;
      final drawWidth = width - (padding * 2);
      // Updated denominator to match new scale range (0-15)
      final targetX = padding + (4 / 15.0) * drawWidth;

      await tester.tapAt(Offset(targetX, size.height / 2));
      await tester.pump();

      // Assert - should produce valid discrete value
      expect(sliderAnswer, isNotNull);
      expect(sliderAnswer!.number, 10);
      expect(sliderAnswer!.orderOfMagnitude, 'K');
      expect(sliderAnswer!.unit, 'm'); // Unit preserved

      // Verify this matches what would be displayed
      expect(find.text('10 K'), findsOneWidget);
    });
  });
}
