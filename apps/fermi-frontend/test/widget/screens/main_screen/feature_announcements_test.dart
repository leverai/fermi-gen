import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/user_limits.dart';
import 'package:fermi_frontend/screens/main/main_screen.dart';

import '../../../helpers/mock_factories.dart';
import '../../../helpers/test_helpers.dart';
import 'main_screen_test_helpers.dart';

void main() {
  late MockApiService mockApi;
  late MockAuthService mockAuth;
  late MockDailyQuestionService mockDailyQuestionService;
  late MockDailyQuestionController mockDailyQuestionController;

  setupMainScreenTests();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockApi = MockApiService();
    mockAuth = MockAuthService();
    mockDailyQuestionService = MockDailyQuestionService();
    mockDailyQuestionController = MockDailyQuestionController();

    when(() => mockApi.getGameConfigTyped()).thenAnswer(
      (_) async => const GameConfig(
        categories: <CategoryInfo>[],
        difficulties: <DifficultyInfo>[],
        ranks: <RankDefinition>[],
        smartSearchEnabled: true,
      ),
    );
    when(() => mockApi.getUserLimitsTyped()).thenAnswer(
      (_) async => const UserLimits(
        partyHostingsRemaining: -1,
        survivalRunsRemaining: 1,
        precisionRushRunsRemaining: 1,
      ),
    );
    when(() => mockApi.getPlayerStatsTyped())
        .thenAnswer((_) async => createTestPlayerStats());
    when(() => mockAuth.firebaseUid).thenReturn('user-a');
    when(() => mockAuth.lastRoundSettings).thenReturn(null);
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.isAnonymous).thenReturn(true);
    when(() => mockDailyQuestionController.isLoading).thenReturn(false);
    when(() => mockDailyQuestionController.errorMessage).thenReturn(null);
    when(() => mockDailyQuestionController.carouselDates)
        .thenReturn(const <String>[]);
    when(() => mockDailyQuestionController.refreshArchiveAndSubscribe())
        .thenAnswer((_) async {});
  });

  testWidgets('shows unseen features and opens Party Settings from the CTA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWithMaterialApp(
      tester,
      ChangeNotifierProvider<DailyQuestionController>.value(
        value: mockDailyQuestionController,
        child: MainScreen(
          apiService: mockApi,
          authService: mockAuth,
          dailyQuestionService: mockDailyQuestionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Smart Search in Party Mode'), findsOneWidget);

    await tester.tap(find.text('Try Smart Search'));
    await tester.pumpAndSettle();

    expect(find.text('Party Settings'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('seen_feature_announcements_user-a'),
      contains('party_smart_search_2026_09'),
    );
  });

  testWidgets('does not show while launch navigation is in progress',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpWithMaterialApp(
      tester,
      ChangeNotifierProvider<DailyQuestionController>.value(
        value: mockDailyQuestionController,
        child: MainScreen(
          apiService: mockApi,
          authService: mockAuth,
          dailyQuestionService: mockDailyQuestionService,
          canShowFeatureAnnouncements: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("What's new"), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('seen_feature_announcements_user-a'),
      isNull,
    );
  });

  testWidgets(
      'does not show when navigation begins while loading announcements',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var readinessChecks = 0;

    await pumpWithMaterialApp(
      tester,
      ChangeNotifierProvider<DailyQuestionController>.value(
        value: mockDailyQuestionController,
        child: MainScreen(
          apiService: mockApi,
          authService: mockAuth,
          dailyQuestionService: mockDailyQuestionService,
          canShowFeatureAnnouncements: () async {
            readinessChecks += 1;
            return readinessChecks == 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(readinessChecks, 2);
    expect(find.text("What's new"), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('seen_feature_announcements_user-a'),
      isNull,
    );
  });
}
