import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/submit_bar.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_pane_state.dart';

import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/circular_determinate_spinner.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SubmitBar - Rendering', () {
    testWidgets('should show submit text when editable',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.started,
        isLast: false,
        isHost: false,
        onSubmit: () {},
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MainButton), findsOneWidget);

      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.label, MainButtonLabel.submit);
      expect(mainButton.onPressed, isNotNull);
    });

    testWidgets('should show next text when revealed (host)',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false, // Not last question
        isHost: true, // User is host
        onSubmit: () {},
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MainButton), findsOneWidget);

      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.label, MainButtonLabel.next);
      expect(mainButton.onPressed, isNotNull); // Should be enabled for host
    });

    testWidgets('should show finish text on last question (host)',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: true, // Last question
        isHost: true, // User is host
        onSubmit: () {},
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MainButton), findsOneWidget);

      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.label, MainButtonLabel.finish);
      expect(mainButton.onPressed, isNotNull);
    });

    testWidgets('should disable button when not host',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false,
        isHost: false, // User is NOT host
        onSubmit: () {},
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MainButton), findsOneWidget);

      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.label, MainButtonLabel.next);
      expect(mainButton.onPressed, isNull); // Should be disabled for non-host
    });

    testWidgets('should show loading state when locked',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.locked,
        isLast: false,
        isHost: true,
        onSubmit: () {},
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester
          .pump(); // Use pump() instead of pumpAndSettle() for loading animations

      // Assert
      expect(find.byType(MainButton), findsOneWidget);

      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.isLoading, true);
      expect(mainButton.onPressed, isNull);
    });
  });

  group('SubmitBar - Progress Indicators', () {
    testWidgets('should not show auto-next progress when state is started',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.started,
        isLast: false,
        isHost: true,
        onSubmit: () {},
        onNext: () {},
        autoNextProgress: 0.5, // Progress value provided but state is started
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // No progress indicator should be shown when state is started
      expect(find.byType(CircularDeterminateSpinner), findsNothing);
    });

    testWidgets('should show auto-next progress after reveal',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false,
        isHost: true,
        onSubmit: () {},
        onNext: () {},
        autoNextProgress: 0.5, // Progress at 50%
        autoNextColor: Colors.blue,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CircularDeterminateSpinner), findsOneWidget);

      final spinner = tester.widget<CircularDeterminateSpinner>(
        find.byType(CircularDeterminateSpinner),
      );
      expect(spinner.progress, 0.5);
      expect(spinner.color, Colors.blue);
    });

    testWidgets('should update progress over time',
        (WidgetTester tester) async {
      // Arrange
      Widget buildWidget(double progress) {
        return SubmitBar(
          state: QuestionPaneState.finished,
          isLast: false,
          isHost: true,
          onSubmit: () {},
          onNext: () {},
          autoNextProgress: progress,
          autoNextColor: Colors.red,
        );
      }

      // Act - Start with 0.3 progress
      await pumpWithMaterialApp(tester, buildWidget(0.3));
      await tester.pumpAndSettle();

      // Verify initial progress
      var spinner = tester.widget<CircularDeterminateSpinner>(
        find.byType(CircularDeterminateSpinner),
      );
      expect(spinner.progress, 0.3);

      // Update to 0.7 progress
      await pumpWithMaterialApp(tester, buildWidget(0.7));
      await tester.pump();

      // Assert - Progress updated
      spinner = tester.widget<CircularDeterminateSpinner>(
        find.byType(CircularDeterminateSpinner),
      );
      expect(spinner.progress, 0.7);
    });

    testWidgets('should not show progress when progress is 0',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false,
        isHost: true,
        onSubmit: () {},
        onNext: () {},
        autoNextProgress: 0.0, // No progress
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Progress indicator should not be shown when progress is 0
      expect(find.byType(CircularDeterminateSpinner), findsNothing);
    });

    testWidgets('should not show progress when progress is 1.0',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false,
        isHost: true,
        onSubmit: () {},
        onNext: () {},
        autoNextProgress: 1.0, // Complete
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Progress indicator should not be shown when progress is complete
      expect(find.byType(CircularDeterminateSpinner), findsNothing);
    });

    testWidgets('should show progress on last question when host',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: true, // Last question
        isHost: true, // Host
        onSubmit: () {},
        onNext: () {},
        autoNextProgress: 0.6,
        autoNextColor: Colors.green,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Progress shown for last question when host (only for host)
      expect(find.byType(CircularDeterminateSpinner), findsOneWidget);

      final spinner = tester.widget<CircularDeterminateSpinner>(
        find.byType(CircularDeterminateSpinner),
      );
      expect(spinner.progress, 0.6);
    });

    testWidgets('should show progress on last question for non-host',
        (WidgetTester tester) async {
      // Arrange
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: true, // Last question
        isHost: false, // Non-host
        onSubmit: () {},
        onNext: () {},
        autoNextProgress: 0.4,
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert
      // Progress should not be shown for non-host on last question
      // (non-host can't advance, button is disabled)
      expect(find.byType(CircularDeterminateSpinner), findsNothing);
    });
  });

  group('SubmitBar - Actions', () {
    testWidgets('should call onSubmit on tap', (WidgetTester tester) async {
      // Arrange
      bool submitCalled = false;
      final widget = SubmitBar(
        state: QuestionPaneState.started,
        isLast: false,
        isHost: false,
        onSubmit: () {
          submitCalled = true;
        },
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.byType(MainButton));
      await tester.pumpAndSettle();

      // Assert
      expect(submitCalled, true);
    });

    testWidgets('should call onNext on tap (host)',
        (WidgetTester tester) async {
      // Arrange
      bool nextCalled = false;
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false,
        isHost: true,
        onSubmit: () {},
        onNext: () {
          nextCalled = true;
        },
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.byType(MainButton));
      await tester.pumpAndSettle();

      // Assert
      expect(nextCalled, true);
    });

    testWidgets('should call onFinish on tap (host)',
        (WidgetTester tester) async {
      // Arrange
      bool finishCalled = false;
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: true, // Last question
        isHost: true,
        onSubmit: () {},
        onNext: () {
          finishCalled = true;
        },
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(find.byType(MainButton));
      await tester.pumpAndSettle();

      // Assert
      expect(finishCalled, true);
    });

    testWidgets('should not trigger action when button is disabled',
        (WidgetTester tester) async {
      // Arrange
      bool nextCalled = false;
      final widget = SubmitBar(
        state: QuestionPaneState.finished,
        isLast: false,
        isHost: false, // Non-host, button should be disabled
        onSubmit: () {},
        onNext: () {
          nextCalled = true;
        },
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Try to tap the disabled button
      await tester.tap(find.byType(MainButton));
      await tester.pumpAndSettle();

      // Assert
      expect(nextCalled, false); // Should not be called
    });

    testWidgets('should not trigger action when in locked state',
        (WidgetTester tester) async {
      // Arrange
      bool submitCalled = false;
      final widget = SubmitBar(
        state: QuestionPaneState.locked,
        isLast: false,
        isHost: true,
        onSubmit: () {
          submitCalled = true;
        },
        onNext: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester
          .pump(); // Use pump() instead of pumpAndSettle() for loading animations

      // Try to tap the loading button
      await tester.tap(find.byType(MainButton));
      await tester.pump();

      // Assert
      expect(submitCalled, false); // Should not be called when locked
    });
  });
}
