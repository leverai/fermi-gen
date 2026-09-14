import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_archive_sheet.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../helpers/mock_factories.dart';

class _MockMainScreenController extends Mock implements MainScreenController {}

void main() {
  testWidgets('opens on the latest question month after a publishing gap',
      (tester) async {
    final dailyQuestionService = MockDailyQuestionService();
    final dailyQuestionController = MockDailyQuestionController();
    final mainScreenController = _MockMainScreenController();

    when(() => dailyQuestionController.todayDate).thenReturn('2026-12-31');
    when(() => dailyQuestionService.getMonthlyArchive(2026, 10)).thenAnswer(
      (_) async => DQLiteArchiveResponse(
        items: const {'2026-10-17': false},
        today: '2026-12-31',
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DailyQuestionService>.value(value: dailyQuestionService),
          ChangeNotifierProvider<DailyQuestionController>.value(
            value: dailyQuestionController,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DailyQuestionArchiveSheet(
              mainScreenController: mainScreenController,
              initialDate: DateTime.utc(2026, 10, 17),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    verify(() => dailyQuestionService.getMonthlyArchive(2026, 10)).called(1);
  });
}
