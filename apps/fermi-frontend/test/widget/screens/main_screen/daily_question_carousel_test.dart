import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_card.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../helpers/mock_factories.dart';

void main() {
  testWidgets('renders non-consecutive historical cards when today has no DQ',
      (tester) async {
    final controller = MockDailyQuestionController();
    const items = {
      '2026-10-17': false,
      '2026-04-04': true,
    };

    when(() => controller.isLoading).thenReturn(false);
    when(() => controller.errorMessage).thenReturn(null);
    when(() => controller.carouselDates).thenReturn(items.keys.toList());
    when(() => controller.weeklyItems).thenReturn(items);
    when(() => controller.todayDate).thenReturn('2026-12-31');
    when(() => controller.todayDocument).thenReturn(null);
    when(() => controller.hasUnseenResults(any())).thenReturn(false);

    await tester.pumpWidget(
      ChangeNotifierProvider<DailyQuestionController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: DailyQuestionCarousel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = tester
        .widgetList<DailyQuestionCard>(find.byType(DailyQuestionCard))
        .toList();
    expect(cards.map((card) => card.date), [
      DateTime(2026, 10, 17),
      DateTime(2026, 4, 4),
    ]);
    expect(find.text('Archive'), findsOneWidget);
  });
}
