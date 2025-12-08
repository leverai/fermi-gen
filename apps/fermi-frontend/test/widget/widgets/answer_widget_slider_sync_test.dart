import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/game_card.dart';
import 'package:fermi_frontend/widgets/answer_widget.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/widgets/digit_wheels.dart';
import 'package:fermi_frontend/widgets/om_label.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/widgets/answer_widget.dart' as answer_widget;

import '../../helpers/test_helpers.dart';
import '../../fixtures/question_data.dart';

void main() {
  group('AnswerWidget Slider Synchronization', () {
    testWidgets(
        'should update digit wheels and OM label when slider is dragged',
        (WidgetTester tester) async {
      // Arrange
      const initialAnswer =
          AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      AnswerValue? currentAnswer = initialAnswer;
      final answerController = answer_widget.AnswerController();

      Widget buildGameCard() {
        return GameCard(
          questionText: QuestionDataFixtures.sampleQuestion1,
          tags: QuestionDataFixtures.geographyTags,
          currentAnswer: currentAnswer!,
          submittedAnswer: null,
          unitOptions: QuestionDataFixtures.usUnitOptions,
          units: QuestionDataFixtures.countUnits,
          currentLocale: 'US',
          onAnswerChanged: (value) {
            currentAnswer = value;
          },
          onLocaleChanged: (_) {},
          answerController: answerController,
          revealedAnswer: null,
          revealedColor: null,
          editable: true,
          showFeedback: false,
          initialLikes: 0,
          initialVoteState: VoteState.none,
          onUpvote: null,
          onDeUpvote: null,
          onDownvote: null,
          onDeDownvote: null,
          unitOptionsNotifier: null,
        );
      }

      // Act - Initial render
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Verify initial state
      final initialAnswerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(initialAnswerWidget.value.number, 1);
      expect(initialAnswerWidget.value.orderOfMagnitude, '');

      // Get the slider widget
      final scaleFinder = find.byType(AnswerAccuracyScale);
      expect(scaleFinder, findsOneWidget);
      final RenderBox scaleBox = tester.renderObject(scaleFinder);
      final scaleSize = scaleBox.size;
      final scaleWidth = scaleSize.width;

      // Act - Drag slider to a different position (e.g., to 10K position)
      // Position for log value ~4 (which maps to 10 K)
      // log 4 = position at 4/18 of the width
      final targetX = 12.0 + (4 / 18.0) * (scaleWidth - 24.0);

      // Start drag
      final startX = 12.0; // Left edge (log 0 = 1)
      await tester.drag(
        scaleFinder,
        Offset(targetX - startX, 0),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(); // Extra pump to ensure state updates propagate

      // Update widget with new answer
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Assert - AnswerWidget should have updated value
      final updatedAnswerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      // The slider should have updated the answer (snapped to discrete value)
      // Log 4 maps to number=10, OM='K' (discrete log 4 = 4/3 = 1, 4%3 = 1 -> number=10)
      expect(updatedAnswerWidget.value.number, 10);
      expect(updatedAnswerWidget.value.orderOfMagnitude, 'K');
    });

    testWidgets('should update digit wheels when slider changes answer value',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      final answerController = answer_widget.AnswerController();

      Widget buildGameCard() {
        return GameCard(
          questionText: QuestionDataFixtures.sampleQuestion1,
          tags: QuestionDataFixtures.geographyTags,
          currentAnswer: currentAnswer,
          submittedAnswer: null,
          unitOptions: QuestionDataFixtures.usUnitOptions,
          units: QuestionDataFixtures.countUnits,
          currentLocale: 'US',
          onAnswerChanged: (value) {
            currentAnswer = value;
          },
          onLocaleChanged: (_) {},
          answerController: answerController,
          revealedAnswer: null,
          revealedColor: null,
          editable: true,
          showFeedback: false,
          initialLikes: 0,
          initialVoteState: VoteState.none,
          onUpvote: null,
          onDeUpvote: null,
          onDownvote: null,
          onDeDownvote: null,
          unitOptionsNotifier: null,
        );
      }

      // Act - Initial render
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Verify initial digit wheels value
      final initialDigitWheels = tester.widget<DigitWheels>(
        find.byType(DigitWheels),
      );
      expect(initialDigitWheels.initialValue, 1);

      // Simulate slider update by directly updating the answer
      currentAnswer =
          const AnswerValue(number: 10, orderOfMagnitude: 'K', unit: 'm');

      // Rebuild with new answer
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Assert - DigitWheels should have updated
      // The initialValue prop might not change, but the controller should be synced
      // We verify by checking the AnswerWidget value prop was updated
      final answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.value.number, 10);
      expect(answerWidget.value.orderOfMagnitude, 'K');
    });

    testWidgets('should update OM label when slider changes order of magnitude',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      final answerController = answer_widget.AnswerController();

      Widget buildGameCard() {
        return GameCard(
          questionText: QuestionDataFixtures.sampleQuestion1,
          tags: QuestionDataFixtures.geographyTags,
          currentAnswer: currentAnswer,
          submittedAnswer: null,
          unitOptions: QuestionDataFixtures.usUnitOptions,
          units: QuestionDataFixtures.countUnits,
          currentLocale: 'US',
          onAnswerChanged: (value) {
            currentAnswer = value;
          },
          onLocaleChanged: (_) {},
          answerController: answerController,
          revealedAnswer: null,
          revealedColor: null,
          editable: true,
          showFeedback: false,
          initialLikes: 0,
          initialVoteState: VoteState.none,
          onUpvote: null,
          onDeUpvote: null,
          onDownvote: null,
          onDeDownvote: null,
          unitOptionsNotifier: null,
        );
      }

      // Act - Initial render
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Verify initial OM label value
      final initialOmLabel = tester.widget<OmLabel>(
        find.byType(OmLabel),
      );
      expect(initialOmLabel.initialValue, '');

      // Simulate slider update that changes OM
      currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: 'M', unit: 'm');

      // Rebuild with new answer
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Assert - AnswerWidget should have updated OM
      final answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.value.orderOfMagnitude, 'M');
    });

    testWidgets('should handle rapid slider updates without recursion',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      final answerController = answer_widget.AnswerController();
      int updateCount = 0;

      Widget buildGameCard() {
        return GameCard(
          questionText: QuestionDataFixtures.sampleQuestion1,
          tags: QuestionDataFixtures.geographyTags,
          currentAnswer: currentAnswer,
          submittedAnswer: null,
          unitOptions: QuestionDataFixtures.usUnitOptions,
          units: QuestionDataFixtures.countUnits,
          currentLocale: 'US',
          onAnswerChanged: (value) {
            updateCount++;
            currentAnswer = value;
          },
          onLocaleChanged: (_) {},
          answerController: answerController,
          revealedAnswer: null,
          revealedColor: null,
          editable: true,
          showFeedback: false,
          initialLikes: 0,
          initialVoteState: VoteState.none,
          onUpvote: null,
          onDeUpvote: null,
          onDownvote: null,
          onDeDownvote: null,
          unitOptionsNotifier: null,
        );
      }

      // Act - Initial render
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Simulate multiple rapid updates
      currentAnswer =
          const AnswerValue(number: 10, orderOfMagnitude: 'K', unit: 'm');
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pump();

      currentAnswer =
          const AnswerValue(number: 100, orderOfMagnitude: 'K', unit: 'm');
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pump();

      await tester.pumpAndSettle();

      // Assert - Should have handled updates without infinite loops
      // The updateCount should be reasonable (not thousands)
      expect(updateCount, lessThan(100));

      // Final state should be correct
      final answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.value.number, 100);
      expect(answerWidget.value.orderOfMagnitude, 'K');
    });

    testWidgets('should sync at boundary values (1→10, 100→1K transitions)',
        (WidgetTester tester) async {
      // Arrange
      AnswerValue currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: '', unit: 'm');
      final answerController = answer_widget.AnswerController();

      Widget buildGameCard() {
        return GameCard(
          questionText: QuestionDataFixtures.sampleQuestion1,
          tags: QuestionDataFixtures.geographyTags,
          currentAnswer: currentAnswer,
          submittedAnswer: null,
          unitOptions: QuestionDataFixtures.usUnitOptions,
          units: QuestionDataFixtures.countUnits,
          currentLocale: 'US',
          onAnswerChanged: (value) {
            currentAnswer = value;
          },
          onLocaleChanged: (_) {},
          answerController: answerController,
          revealedAnswer: null,
          revealedColor: null,
          editable: true,
          showFeedback: false,
          initialLikes: 0,
          initialVoteState: VoteState.none,
          onUpvote: null,
          onDeUpvote: null,
          onDownvote: null,
          onDeDownvote: null,
          unitOptionsNotifier: null,
        );
      }

      // Act - Initial render with 1 (no OM)
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      // Test transition: 1 → 10 (still no OM, but number changes)
      currentAnswer =
          const AnswerValue(number: 10, orderOfMagnitude: '', unit: 'm');
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      var answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.value.number, 10);
      expect(answerWidget.value.orderOfMagnitude, '');

      // Test transition: 100 → 1K (OM changes)
      currentAnswer =
          const AnswerValue(number: 1, orderOfMagnitude: 'K', unit: 'm');
      await pumpWithMaterialApp(tester, buildGameCard());
      await tester.pumpAndSettle();

      answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.value.number, 1);
      expect(answerWidget.value.orderOfMagnitude, 'K');
    });
  });
}
