import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:like_button/like_button.dart';

import '../../../helpers/test_helpers.dart';
import '../../../fixtures/question_data.dart';

void main() {
  group('QuestionWidget - Voting', () {
    testWidgets('should call onUpvote on upvote tap', (WidgetTester tester) async {
      // Arrange
      bool upvoteCalled = false;
      const questionText = QuestionDataFixtures.sampleQuestion1;
      final widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {
          upvoteCalled = true;
        },
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Find the first LikeButton (upvote button) and tap it
      // The AnimatedLikeDislike widget has two LikeButton widgets in a Row
      // The first one is the upvote button
      final likeButtons = find.byType(LikeButton);
      expect(likeButtons, findsNWidgets(2)); // Upvote and downvote buttons
      await tester.tap(likeButtons.first);
      await tester.pumpAndSettle();

      // Assert
      expect(upvoteCalled, isTrue);
    });

    testWidgets('should call onDownvote on downvote tap', (WidgetTester tester) async {
      // Arrange
      bool downvoteCalled = false;
      const questionText = QuestionDataFixtures.sampleQuestion1;
      final widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {
          downvoteCalled = true;
        },
        onDeDownvote: () async {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Find the second LikeButton (downvote button) and tap it
      // The AnimatedLikeDislike widget has two LikeButton widgets in a Row
      // The second one is the downvote button
      final likeButtons = find.byType(LikeButton);
      expect(likeButtons, findsNWidgets(2)); // Upvote and downvote buttons
      await tester.tap(likeButtons.at(1)); // Tap the second one (downvote)
      await tester.pumpAndSettle();

      // Assert
      expect(downvoteCalled, isTrue);
    });

    testWidgets('should update vote state', (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      final widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: true,
        initialLikes: 5,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
        likeWidgetKey: const ValueKey('like_widget'),
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Initially should show outlined icons (not voted)
      expect(find.byIcon(Icons.thumb_up_outlined), findsWidgets);
      expect(find.byIcon(Icons.thumb_up), findsNothing);

      // Tap upvote button (first LikeButton)
      final likeButtons = find.byType(LikeButton);
      expect(likeButtons, findsNWidgets(2));
      await tester.tap(likeButtons.first);
      await tester.pumpAndSettle();

      // Assert - should now show filled upvote icon
      // Note: The AnimatedLikeDislike widget updates its internal state
      // We verify by checking that the like count increased
      expect(find.text('6'), findsOneWidget); // 5 + 1 = 6
    });

    testWidgets('should update upvote count', (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const initialLikes = 10;
      final widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: true,
        initialLikes: initialLikes,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Verify initial count
      expect(find.text('10'), findsOneWidget);

      // Tap upvote button (first LikeButton)
      final likeButtons = find.byType(LikeButton);
      expect(likeButtons, findsNWidgets(2));
      await tester.tap(likeButtons.first);
      await tester.pumpAndSettle();

      // Assert - count should increase
      expect(find.text('11'), findsOneWidget);
    });

    testWidgets('should animate vote button', (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      final widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: true,
        initialLikes: 0,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Tap upvote button (first LikeButton)
      final likeButtons = find.byType(LikeButton);
      expect(likeButtons, findsNWidgets(2));
      await tester.tap(likeButtons.first);

      // Wait for animation to complete
      await tester.pumpAndSettle();

      // Assert - animation should complete without errors
      // The LikeButton widget from like_button package handles animations
      // We verify by checking the widget is still present and functional
      expect(find.byType(AnimatedLikeDislike), findsOneWidget);
    });
  });
}
