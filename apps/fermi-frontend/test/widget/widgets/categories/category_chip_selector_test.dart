import 'package:fermi_frontend/widgets/categories/category_chip_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CategoryChipSelector UI test', (WidgetTester tester) async {
    // 1. Setup - Create categories to test selection
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

    // 2. Verify initial state - placeholder always visible, "All" chip checked
    expect(find.text('E.g. Christmas'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);

    // 3. Verify "All" checkbox is checked initially (icon is check_box)
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    // 4. Select a category - this should uncheck "All"
    await tester.tap(find.widgetWithText(CategoryChip, 'Category 0'));
    await tester.pumpAndSettle();

    // 5. Verify "All" is now unchecked
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNothing);

    // 6. Verify category only appears once (not in input box anymore)
    expect(find.text('Category 0'), findsOneWidget);

    // 7. Click "All" chip - should deselect all categories
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // 8. Verify "All" is checked again
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);

    // 9. Verify placeholder is still visible
    expect(find.text('E.g. Christmas'), findsOneWidget);
  });
}
