import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/screens/main/widgets/primary_cta.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('PrimaryCta - Label Display', () {
    testWidgets('should display "Create" label when isLocked is true',
        (WidgetTester tester) async {
      // ARRANGE
      const widget = PrimaryCta(
        isLoading: false,
        onPressed: null,
        isLocked: true,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byType(MainButton), findsOneWidget);
      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.label, MainButtonLabel.create);
    });

    testWidgets('should display "Join" label when isLocked is false',
        (WidgetTester tester) async {
      // ARRANGE
      const widget = PrimaryCta(
        isLoading: false,
        onPressed: null,
        isLocked: false,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT
      expect(find.byType(MainButton), findsOneWidget);
      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.label, MainButtonLabel.join);
    });

    testWidgets('should show spacebar glyph', (WidgetTester tester) async {
      // ARRANGE
      const widget = PrimaryCta(
        isLoading: false,
        onPressed: null,
        isLocked: false,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT
      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.showSpacebarGlyph, true);
    });

    testWidgets('should pass isLoading state to MainButton',
        (WidgetTester tester) async {
      // ARRANGE
      final widget = PrimaryCta(
        isLoading: true,
        onPressed: () {},
        isLocked: false,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester
          .pump(); // Use pump() instead of pumpAndSettle() for loading animations

      // ASSERT
      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.isLoading, true);
      expect(mainButton.onPressed, isNull); // Disabled when loading
    });

    testWidgets('should pass onPressed callback to MainButton when not loading',
        (WidgetTester tester) async {
      // ARRANGE
      final widget = PrimaryCta(
        isLoading: false,
        onPressed: () {},
        isLocked: false,
      );

      // ACT
      await pumpWithMaterialApp(tester, widget);
      await tester.pumpAndSettle();

      // ASSERT
      final mainButton = tester.widget<MainButton>(
        find.byType(MainButton),
      );
      expect(mainButton.isLoading, false);
      expect(mainButton.onPressed, isNotNull);
    });
  });
}
