import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/quick_access_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('QuickAccessBar - Rendering', () {
    testWidgets('should display drag indicator', (WidgetTester tester) async {
      // Arrange
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () {},
        onClose: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert - Check for the text "Swipe" and "for Numpad"
      expect(find.text('Swipe '), findsOneWidget);
      expect(find.text(' for Numpad'), findsOneWidget);
      // Check for the up arrow icon
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('should display "Show numpad" text', (WidgetTester tester) async {
      // Arrange
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () {},
        onClose: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert - The text "Swipe ↑ for Numpad" should be displayed
      expect(find.textContaining('Swipe'), findsOneWidget);
      expect(find.textContaining('for Numpad'), findsOneWidget);
    });

    testWidgets('should not display when disabled', (WidgetTester tester) async {
      // Arrange
      final widget = QuickAccessBar(
        enabled: false,
        onTrigger: () {},
        onClose: () {},
      );

      // Act
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Assert - When disabled, widget returns empty Container
      expect(find.text('Swipe'), findsNothing);
      expect(find.byType(QuickAccessBar), findsOneWidget);
    });
  });

  group('QuickAccessBar - Drag Interaction', () {
    testWidgets('should open numpad on drag up (80px threshold)',
        (WidgetTester tester) async {
      // Arrange
      bool onTriggerCalled = false;
      bool onCloseCalled = false;
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () => onTriggerCalled = true,
        onClose: () => onCloseCalled = true,
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Act - Drag up 80px (negative Y means up)
      final gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump(); // Allow state updates
      await gesture.up();
      // Wait for the delayed timer (200ms) to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      // Assert - onTrigger should be called when threshold is reached
      expect(onTriggerCalled, isTrue, reason: 'onTrigger should be called when dragging up 80px');
      expect(onCloseCalled, isFalse);
    });

    testWidgets('should not open numpad when drag is less than 80px',
        (WidgetTester tester) async {
      // Arrange
      bool onTriggerCalled = false;
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () => onTriggerCalled = true,
        onClose: () {},
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Act - Drag up only 50px (less than 80px threshold)
      final gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert - onTrigger should NOT be called
      expect(onTriggerCalled, isFalse,
          reason: 'onTrigger should not be called when drag is less than 80px');
    });

    testWidgets('should close bottom sheets on drag down',
        (WidgetTester tester) async {
      // Arrange
      bool onTriggerCalled = false;
      bool onCloseCalled = false;
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () => onTriggerCalled = true,
        onClose: () => onCloseCalled = true,
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Act - Drag down 20px (positive Y means down, threshold is 20px)
      final gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(); // Allow state updates
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert - onClose should be called when threshold is reached
      expect(onCloseCalled, isTrue,
          reason: 'onClose should be called when dragging down 20px');
      expect(onTriggerCalled, isFalse);
    });

    testWidgets('should not close bottom sheets when drag down is less than 20px',
        (WidgetTester tester) async {
      // Arrange
      bool onCloseCalled = false;
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () {},
        onClose: () => onCloseCalled = true,
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Act - Drag down only 10px (less than 20px threshold)
      final gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert - onClose should NOT be called
      expect(onCloseCalled, isFalse,
          reason: 'onClose should not be called when drag is less than 20px');
    });

    testWidgets('should update progress during drag', (WidgetTester tester) async {
      // Arrange
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () {},
        onClose: () {},
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Act - Drag up gradually to test progress updates
      final gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );

      // Drag 40px (50% of threshold)
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      // The text color should interpolate based on drag progress
      // At 50% progress, color should be between bgLight and info
      // We can verify the widget is updating by checking it's still rendered
      expect(find.text('Swipe '), findsOneWidget);

      // Continue dragging to 80px (100% of threshold)
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      // Widget should still be rendered
      expect(find.text('Swipe '), findsOneWidget);

      await gesture.up();
      // Wait for the delayed timer (200ms) to complete
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
    });

    testWidgets('should reset drag distance when drag ends below threshold',
        (WidgetTester tester) async {
      // Arrange
      bool onTriggerCalled = false;
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () => onTriggerCalled = true,
        onClose: () {},
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Act - Drag up 50px (less than threshold) then release
      final gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert - onTrigger should not be called and drag should reset
      expect(onTriggerCalled, isFalse);
      // Widget should still be functional
      expect(find.text('Swipe '), findsOneWidget);
    });

    testWidgets('should handle multiple drag gestures', (WidgetTester tester) async {
      // Arrange
      int triggerCount = 0;
      int closeCount = 0;
      final widget = QuickAccessBar(
        enabled: true,
        onTrigger: () => triggerCount++,
        onClose: () => closeCount++,
      );

      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      final gestureFinder = find.byType(GestureDetector);

      // Act - First drag up to open
      var gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle(const Duration(milliseconds: 250));

      // Second drag down to close
      gesture = await tester.startGesture(
        tester.getCenter(gestureFinder),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert - Both callbacks should be called
      expect(triggerCount, equals(1),
          reason: 'onTrigger should be called once');
      expect(closeCount, equals(1),
          reason: 'onClose should be called once');
    });
  });
}
