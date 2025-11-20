import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/game_card.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/answer_widget.dart';
import 'package:fermi_frontend/widgets/answer_mirror_text.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:fermi_frontend/models/answer_value.dart';

import '../../helpers/test_helpers.dart';
import '../../fixtures/question_data.dart';

void main() {
  group('GameCard - Rendering', () {
    testWidgets('should display question widget', (WidgetTester tester) async {
      // Arrange
      const questionKey = ValueKey('test_question');
      final widget = GameCard(
        questionWidgetKey: questionKey,
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
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

      // Act
      await pumpWithMaterialApp(tester, widget);

      // Assert
      expect(find.byKey(questionKey), findsOneWidget);
      expect(find.byType(QuestionWidget), findsOneWidget);
      expect(find.text(QuestionDataFixtures.sampleQuestion1), findsOneWidget);
    });

    testWidgets('should display answer widget', (WidgetTester tester) async {
      // Arrange
      const answerKey = ValueKey('test_answer');
      final widget = GameCard(
        answerWidgetKey: answerKey,
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 123, orderOfMagnitude: 'M', unit: 'km'),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
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

      // Act
      await pumpWithMaterialApp(tester, widget);

      // Assert
      expect(find.byKey(answerKey), findsOneWidget);
      expect(find.byType(AnswerWidget), findsOneWidget);
    });

    testWidgets('should display answer mirror text',
        (WidgetTester tester) async {
      // Arrange
      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 456, orderOfMagnitude: 'K', unit: 'kg'),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
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

      // Act
      await pumpWithMaterialApp(tester, widget);

      // Assert
      expect(find.byType(AnswerMirrorText), findsOneWidget);
    });

    testWidgets('should not display feedback row before reveal',
        (WidgetTester tester) async {
      // Arrange
      const likeKey = ValueKey('test_like');
      final widget = GameCard(
        likeWidgetKey: likeKey,
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer: null,
        revealedColor: null,
        editable: true,
        showFeedback: false, // No feedback yet
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: null,
        onDeUpvote: null,
        onDownvote: null,
        onDeDownvote: null,
        unitOptionsNotifier: null,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);

      // Assert
      // AnimatedLikeDislike widget exists but should be hidden via AnimatedOpacity with opacity 0
      expect(find.byType(AnimatedLikeDislike), findsOneWidget);
      final likeWidget = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(AnimatedLikeDislike),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(likeWidget.opacity, 0.0);
    });

    testWidgets('should display feedback row after reveal',
        (WidgetTester tester) async {
      // Arrange
      const likeKey = ValueKey('test_like');
      final widget = GameCard(
        likeWidgetKey: likeKey,
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer: null,
        revealedColor: null,
        editable: false,
        showFeedback: true, // Show feedback after reveal
        initialLikes: 5,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        unitOptionsNotifier: null,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle(); // Wait for animations to complete

      // Assert
      expect(find.byKey(likeKey), findsOneWidget);
      expect(find.byType(AnimatedLikeDislike), findsOneWidget);
      final likeWidget = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(AnimatedLikeDislike),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(likeWidget.opacity, 1.0);
    });

    testWidgets('should animate opacity when feedback appears',
        (WidgetTester tester) async {
      // Arrange
      // Start with no feedback
      Widget buildWidget(bool showFeedback) {
        return GameCard(
          questionText: QuestionDataFixtures.sampleQuestion1,
          tags: QuestionDataFixtures.geographyTags,
          currentAnswer:
              const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
          submittedAnswer: null,
          unitOptions: QuestionDataFixtures.usUnitOptions,
          units: QuestionDataFixtures.countUnits,
          currentLocale: 'US',
          onAnswerChanged: (_) {},
          onLocaleChanged: (_) {},
          answerController: null,
          revealedAnswer: null,
          revealedColor: null,
          editable: !showFeedback,
          showFeedback: showFeedback,
          initialLikes: 0,
          initialVoteState: VoteState.none,
          onUpvote: showFeedback ? () async {} : null,
          onDeUpvote: showFeedback ? () async {} : null,
          onDownvote: showFeedback ? () async {} : null,
          onDeDownvote: showFeedback ? () async {} : null,
          unitOptionsNotifier: null,
        );
      }

      // Act - Start without feedback
      await pumpWithMaterialApp(tester, buildWidget(false));
      await tester.pumpAndSettle();

      // Verify feedback is hidden
      final likeWidgetBefore = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(AnimatedLikeDislike),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(likeWidgetBefore.opacity, 0.0);

      // Act - Update to show feedback
      await pumpWithMaterialApp(tester, buildWidget(true));
      await tester.pump(); // Start animation

      // Verify animation is in progress (opacity between 0 and 1)
      final likeWidgetDuring = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(AnimatedLikeDislike),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(likeWidgetDuring.opacity, 1.0); // Target opacity is set

      // Complete the animation
      await tester.pumpAndSettle();

      // Assert - Feedback is fully visible
      final likeWidgetAfter = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(AnimatedLikeDislike),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(likeWidgetAfter.opacity, 1.0);
    });

    testWidgets('should display divider between question and answer',
        (WidgetTester tester) async {
      // Arrange
      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
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

      // Act
      await pumpWithMaterialApp(tester, widget);

      // Assert
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('GameCard - State Management', () {
    testWidgets('should show editable answer before reveal',
        (WidgetTester tester) async {
      // Arrange
      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer: null,
        revealedColor: null,
        editable: true, // Answer should be editable
        showFeedback: false,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: null,
        onDeUpvote: null,
        onDownvote: null,
        onDeDownvote: null,
        unitOptionsNotifier: null,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify AnswerWidget is editable by checking the editable property
      final answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.editable, true);
    });

    testWidgets('should show revealed answer after reveal',
        (WidgetTester tester) async {
      // Arrange
      const revealedAnswer =
          AnswerValue(number: 500, orderOfMagnitude: 'M', unit: 'km');
      const revealedColor = Colors.green;

      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 123, orderOfMagnitude: 'K', unit: 'km'),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer: revealedAnswer,
        revealedColor: revealedColor,
        editable: false, // Not editable after reveal
        showFeedback: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        unitOptionsNotifier: null,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle(); // Wait for reveal animation

      // Assert
      // Verify AnswerWidget received revealed answer and color
      final answerWidget = tester.widget<AnswerWidget>(
        find.byType(AnswerWidget),
      );
      expect(answerWidget.editable, false);
      expect(answerWidget.revealedAnswer, revealedAnswer);
      expect(answerWidget.revealedColor, revealedColor);
    });

    testWidgets('should show submitted answer in mirror text after reveal',
        (WidgetTester tester) async {
      // Arrange
      const submittedAnswer =
          AnswerValue(number: 123, orderOfMagnitude: 'K', unit: 'km');
      const revealedAnswer =
          AnswerValue(number: 500, orderOfMagnitude: 'M', unit: 'km');

      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer: revealedAnswer, // Current value is now revealed answer
        submittedAnswer: submittedAnswer, // Player's submitted answer
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer: revealedAnswer,
        revealedColor: Colors.green,
        editable: false, // Not editable during reveal
        showFeedback: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        unitOptionsNotifier: null,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify AnswerMirrorText received both submitted and current answers
      final mirrorText = tester.widget<AnswerMirrorText>(
        find.byType(AnswerMirrorText),
      );
      expect(mirrorText.value, revealedAnswer);
      expect(mirrorText.submittedAnswer, submittedAnswer);
      expect(mirrorText.editable, false);
    });

    testWidgets('should pass revealed color to question widget',
        (WidgetTester tester) async {
      // Arrange
      const revealedColor = Colors.blue;

      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer:
            const AnswerValue(number: 500, orderOfMagnitude: 'M', unit: 'km'),
        revealedColor: revealedColor,
        editable: false,
        showFeedback: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        unitOptionsNotifier: null,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Verify QuestionWidget received revealed color
      final questionWidget = tester.widget<QuestionWidget>(
        find.byType(QuestionWidget),
      );
      expect(questionWidget.revealedColor, revealedColor);
    });

    testWidgets('should disable copy in editable mode',
        (WidgetTester tester) async {
      // Arrange
      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer: null,
        revealedColor: null,
        editable: true, // In editable mode
        showFeedback: false, // No feedback
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: null,
        onDeUpvote: null,
        onDownvote: null,
        onDeDownvote: null,
        unitOptionsNotifier: null,
        reviewMode: false, // Not in review mode
      );

      // Act
      await pumpWithScaffold(tester, widget);
      await tester.pumpAndSettle();

      // Long press should not show snackbar (copy disabled)
      final questionText = find.text(QuestionDataFixtures.sampleQuestion1);
      await tester.longPress(questionText);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Question copied to clipboard'), findsNothing);
    });

    testWidgets('should enable copy after reveal',
        (WidgetTester tester) async {
      // Arrange
      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer:
            const AnswerValue(number: 500, orderOfMagnitude: 'M', unit: 'km'),
        revealedColor: Colors.green,
        editable: false,
        showFeedback: true, // Feedback shown after reveal
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        unitOptionsNotifier: null,
        reviewMode: false,
      );

      // Act
      await pumpWithScaffold(tester, widget);
      await tester.pumpAndSettle();

      // Long press should show snackbar (copy enabled after reveal)
      final questionText = find.text(QuestionDataFixtures.sampleQuestion1);
      await tester.longPress(questionText);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Question copied to clipboard'), findsOneWidget);
    });

    testWidgets('should enable copy in review mode',
        (WidgetTester tester) async {
      // Arrange
      final widget = GameCard(
        questionText: QuestionDataFixtures.sampleQuestion1,
        tags: QuestionDataFixtures.geographyTags,
        currentAnswer:
            const AnswerValue(number: 1, orderOfMagnitude: '', unit: ''),
        submittedAnswer: null,
        unitOptions: QuestionDataFixtures.usUnitOptions,
        units: QuestionDataFixtures.countUnits,
        currentLocale: 'US',
        onAnswerChanged: (_) {},
        onLocaleChanged: (_) {},
        answerController: null,
        revealedAnswer:
            const AnswerValue(number: 500, orderOfMagnitude: 'M', unit: 'km'),
        revealedColor: Colors.green,
        editable: false,
        showFeedback: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        unitOptionsNotifier: null,
        reviewMode: true, // In review mode
      );

      // Act
      await pumpWithScaffold(tester, widget);
      await tester.pumpAndSettle();

      // Long press should show snackbar (copy enabled in review mode)
      final questionText = find.text(QuestionDataFixtures.sampleQuestion1);
      await tester.longPress(questionText);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Question copied to clipboard'), findsOneWidget);
    });
  });
}
