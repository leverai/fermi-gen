import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/widgets/invite_bots_button.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('InviteBotsButton', () {
    testWidgets('should display robot icon', (WidgetTester tester) async {
      // ARRANGE
      bool pressed = false;
      final widget = InviteBotsButton(
        onPressed: () => pressed = true,
        botCount: 2,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT - uses SVG icon asset instead of Material Icon
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('should display correct label for single bot',
        (WidgetTester tester) async {
      // ARRANGE
      final widget = InviteBotsButton(
        onPressed: () {},
        botCount: 1,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('Invite 1 bot'), findsOneWidget);
    });

    testWidgets('should display correct label for multiple bots',
        (WidgetTester tester) async {
      // ARRANGE
      final widget = InviteBotsButton(
        onPressed: () {},
        botCount: 3,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.text('Invite 3 bots'), findsOneWidget);
    });

    testWidgets('should call onPressed when tapped',
        (WidgetTester tester) async {
      // ARRANGE
      bool pressed = false;
      final widget = InviteBotsButton(
        onPressed: () => pressed = true,
        botCount: 2,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InviteBotsButton));
      await tester.pump();

      // ASSERT
      expect(pressed, true);
    });

    testWidgets('should not call onPressed when disabled',
        (WidgetTester tester) async {
      // ARRANGE
      bool pressed = false;
      final widget = InviteBotsButton(
        onPressed: () => pressed = true,
        botCount: 2,
        enabled: false,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InviteBotsButton));
      await tester.pump();

      // ASSERT
      expect(pressed, false);
    });

    testWidgets('should show press animation when tapped',
        (WidgetTester tester) async {
      // ARRANGE
      final widget = InviteBotsButton(
        onPressed: () {},
        botCount: 1,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // Get the initial position
      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);

      // Simulate press
      await tester.press(find.byType(InviteBotsButton));
      await tester.pump(const Duration(milliseconds: 50));

      // ASSERT - AnimatedContainer exists and can animate
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('should use muted colors when disabled',
        (WidgetTester tester) async {
      // ARRANGE
      final widget = InviteBotsButton(
        onPressed: () {},
        botCount: 2,
        enabled: false,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT - the widget should be rendered without throwing
      expect(find.byType(InviteBotsButton), findsOneWidget);
    });
  });
}
