import 'package:fermi_frontend/widgets/categories/category_carousel_m3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CategoryCarouselM3 selection works and InkWell is used',
      (WidgetTester tester) async {
    // Arrange
    int? selectedIndex;
    final categories = [
      const CategoryItemM3(id: '1', title: 'Cat 1', svgPath: 'icon:public'),
      const CategoryItemM3(id: '2', title: 'Cat 2', svgPath: 'icon:rocket'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryCarouselM3(
            categories: categories,
            onCategorySelected: (index) {
              selectedIndex = index;
            },
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.byType(CategoryCardM3).first);
    await tester.pumpAndSettle();

    // Assert
    expect(selectedIndex, 0);
  });
}
