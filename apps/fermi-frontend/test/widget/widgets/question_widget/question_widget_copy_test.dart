import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';

import '../../../helpers/test_helpers.dart';
import '../../../fixtures/question_data.dart';

void main() {
  group('QuestionWidget - Copy Feature', () {
    testWidgets('should not have built-in copy functionality',
        (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const widget = QuestionWidget(
        text: questionText,
      );

      // Act
      await pumpWithScaffold(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // QuestionWidget is a presentational component and does not handle copy functionality.
      // Copy functionality is handled by the parent widget (GameCard) which wraps QuestionWidget
      // in an InkWell with onLongPress. This test verifies that QuestionWidget doesn't
      // interfere with parent gesture handling.
      expect(find.text(questionText), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.text('Question copied to clipboard'), findsNothing);
    });

    testWidgets(
        'should allow parent widgets to handle copy via gesture detection',
        (WidgetTester tester) async {
      // Arrange
      const questionText = QuestionDataFixtures.sampleQuestion1;
      const widget = QuestionWidget(
        text: questionText,
      );

      // Act
      await pumpWithScaffold(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // QuestionWidget should not prevent parent widgets from handling gestures.
      // The widget should render normally and allow parent InkWell/GestureDetector
      // to handle long press events for copy functionality.
      final questionTextFinder = find.text(questionText);
      expect(questionTextFinder, findsOneWidget);

      // Long press should not crash (parent will handle it if present)
      await tester.longPress(questionTextFinder);
      await tester.pumpAndSettle();

      // Widget should still be present after gesture
      expect(find.text(questionText), findsOneWidget);
    });
  });
}
