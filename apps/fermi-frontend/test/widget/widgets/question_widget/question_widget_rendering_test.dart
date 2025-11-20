import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/tag_widget.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';

import '../../../helpers/test_helpers.dart';
import '../../../fixtures/question_data.dart';

void main() {
  group('QuestionWidget - Rendering', () {
    testWidgets('should display question text', (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const widget = QuestionWidget(
        text: questionText,
        height: 200,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);

      // Assert
      expect(find.text(questionText), findsOneWidget);
    });

    testWidgets('should display tags', (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const tags = QuestionDataFixtures.geographyTags;
      const widget = QuestionWidget(
        text: questionText,
        tags: tags,
        height: 200,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      for (final tag in tags) {
        expect(find.text(tag), findsOneWidget);
      }
      // Verify TagWidget instances are present
      expect(find.byType(TagWidget), findsNWidgets(tags.length));
    });

    testWidgets(
        'should display like/dislike widget when showLikeWidget is true',
        (WidgetTester tester) async {
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
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AnimatedLikeDislike), findsOneWidget);
    });

    testWidgets(
        'should not display like/dislike widget when showLikeWidget is false',
        (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: false,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AnimatedLikeDislike), findsNothing);
    });

    testWidgets('should show upvote count', (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const upvoteCount = 42;
      final widget = QuestionWidget(
        text: questionText,
        height: 200,
        showLikeWidget: true,
        initialLikes: upvoteCount,
        initialVoteState: VoteState.none,
        onUpvote: () async {},
        onDeUpvote: () async {},
        onDownvote: () async {},
        onDeDownvote: () async {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // The AnimatedLikeDislike widget formats numbers using NumberFormat.compact
      // So 42 should be displayed as "42"
      expect(find.text('42'), findsOneWidget);
    });
  });
}
