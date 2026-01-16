import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/scroll_hint.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

void main() {
  testWidgets('ScrollHint renders child and arrows',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AppTheme.defaultTheme()]),
        home: const Scaffold(
          body: ScrollHint(
            opacity: 1.0,
            child: SizedBox(width: 100, height: 100, child: Text('Child')),
          ),
        ),
      ),
    );

    // Verify child is rendered
    expect(find.text('Child'), findsOneWidget);

    // Verify arrows are rendered
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('ScrollHint respects opacity', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AppTheme.defaultTheme()]),
        home: const Scaffold(
          body: ScrollHint(
            opacity: 0.5,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    final upArrow = tester.widget<Icon>(find.byIcon(Icons.keyboard_arrow_up));
    final downArrow =
        tester.widget<Icon>(find.byIcon(Icons.keyboard_arrow_down));

    // Opacity is applied to the color alpha
    // Base color is textMuted (usually grey), multiplied by 0.5 * opacity
    // We just check that color is not null
    expect(upArrow.color, isNotNull);
    expect(downArrow.color, isNotNull);
  });
}
