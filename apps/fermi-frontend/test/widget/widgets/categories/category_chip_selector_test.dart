import 'package:fermi_frontend/widgets/categories/category_chip_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categories = List.generate(
    10,
    (index) => CategoryChipItem(id: '$index', title: 'Category $index'),
  );

  testWidgets('chip selection toggles the "All" chip (search disabled)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChipSelector(categories: categories),
        ),
      ),
    );

    // Search box hidden by default; no TextField rendered.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('All'), findsOneWidget);

    // "All" checkbox is checked initially (nothing selected).
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    // Select a category -> "All" unchecks.
    await tester.tap(find.widgetWithText(CategoryChip, 'Category 0'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNothing);

    // Tap "All" -> deselects all.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
  });

  testWidgets('renders the real search box when searchEnabled is true',
      (WidgetTester tester) async {
    final searchController = TextEditingController();
    String? lastChange;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChipSelector(
            categories: categories,
            searchEnabled: true,
            searchController: searchController,
            onSearchChanged: (v) => lastChange = v,
          ),
        ),
      ),
    );

    // A real TextField now exists with the hint, not "(Coming Soon)".
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('E.g. How many X in Y, Christmas'), findsOneWidget);
    expect(find.text('(Coming Soon)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'space scale');
    expect(lastChange, 'space scale');

    searchController.dispose();
  });

  testWidgets('shows the inline searchError under the box',
      (WidgetTester tester) async {
    final searchController = TextEditingController(text: 'asdfqwer');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChipSelector(
            categories: categories,
            searchEnabled: true,
            searchController: searchController,
            isSearching: true,
            searchError: "No questions match 'asdfqwer' — try a broader search",
          ),
        ),
      ),
    );

    expect(find.text("No questions match 'asdfqwer' — try a broader search"),
        findsOneWidget);

    searchController.dispose();
  });
}
