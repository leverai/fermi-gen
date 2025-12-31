import 'package:fermi_frontend/widgets/categories/category_chip_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CategoryChipSelector UI test', (WidgetTester tester) async {
    // 1. Setup - Create enough categories to cause overflow if needed, or just enough to test selection
    final categories = List.generate(
      10,
      (index) => CategoryChipItem(id: '$index', title: 'Category $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChipSelector(
            categories: categories,
          ),
        ),
      ),
    );

    // 2. Verify initial state
    expect(find.text('E.g. Christmas'), findsOneWidget);

    // 3. Interact: Select multiple categories to fill the input box
    // Finding Category 9 might require scrolling the selection area IF the Wrap overflows the screen?
    // But Wrap goes downward. The screen might be infinite height in test unless constrained?
    // Let's assume we can tap them.
    for (int i = 0; i < 5; i++) {
      await tester.tap(find.widgetWithText(CategoryChip, 'Category $i'));
      await tester.pumpAndSettle(); // Allow animations (scroll) to complete
    }

    // 4. Verify selection state
    expect(find.text('Category 0'), findsNWidgets(2)); // Input + Selection

    // 5. Verify Scroll Controller attached (Implicitly by no errors during pumpAndSettle)
    // We can try to find the Scrollable in the input box and check position?
    // The input box is the FIRST SingleChildScrollView (or check by key/structure).
    // Let's verify that we can see the LAST added item in the input box.
    // Ensure 'Category 4' is visible in the input box.
    // Note: findsNWidgets(2) means it is in the tree. visibleToUser checks viewport.

    // Let's try to verify if it scrolled by adding A LOT of items.
    // If we add 20 items, the first ones should be off screen in the input box if it scrolled to end.
    // But this depends on screen size in test. Default is 800x600.

    // 6. Interact: Deselect
    await tester.tap(find
        .widgetWithText(CategoryChip, 'Category 0')
        .last); // Tap inside selection area
    await tester.pumpAndSettle();

    expect(find.text('Category 0'), findsOneWidget); // Only in selection area
  });
}
