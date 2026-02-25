import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/screens/main/main_screen.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fermi_frontend/firebase_options.dart';
import '../../../helpers/test_helpers.dart';
import '../../../helpers/mock_factories.dart';

/// Shared test setup for MainScreen widget tests
void setupMainScreenTests() {
  setUpAll(() async {
    registerFallbackValues();
    // Initialize Firebase for widget tests
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Use auth emulator to avoid real Firebase calls
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    } catch (e) {
      // Firebase may already be initialized, which is fine
      if (!e.toString().contains('already been initialized') &&
          !e.toString().contains('already in use')) {
        // Ignore initialization errors for widget tests
      }
    }
  });
}

/// Helper to create a test GameConfig
GameConfig createTestGameConfig() {
  return const GameConfig(
    categories: [
      CategoryInfo(
        index: 0,
        name: 'GENERAL',
        slug: 'General',
        picture: 'https://example.com/general.svg',
      ),
      CategoryInfo(
        index: 1,
        name: 'PHYSICS',
        slug: 'Physics',
        picture: 'https://example.com/physics.svg',
      ),
    ],
    difficulties: [
      DifficultyInfo(
          name: 'EASY', slug: 'Easy', picture: 'https://example.com/easy.svg'),
      DifficultyInfo(
          name: 'MEDIUM',
          slug: 'Medium',
          picture: 'https://example.com/medium.svg'),
    ],
    ranks: [],
  );
}

/// Helper to create test PlayerStatsResponse
PlayerStatsResponse createTestPlayerStats({int? averagePercentile}) {
  return PlayerStatsResponse(
    playerId: 'test-player',
    stats: PlayerStats(
      totalPartyGames: 10,
      totalDailyGuesses: 5,
      totalSurvivalRuns: 0,
      averagePercentile: averagePercentile ?? 75,
      level: 1,
      points: 1000,
      rank: const RankInfo(
        id: 1,
        name: 'Observer',
        picture: '',
      ),
    ),
  );
}

/// Helper to setup successful initialization
Future<void> setupInitializedMainScreen(
  WidgetTester tester,
  MockApiService mockApi,
  MockAuthService mockAuth, {
  MockDailyQuestionService? mockDailyQuestionService,
  bool withStats = false,
}) async {
  final config = createTestGameConfig();
  when(() => mockApi.getGameConfigTyped()).thenAnswer((_) async => config);
  when(() => mockAuth.firebaseUid).thenReturn(withStats ? 'test-player' : null);
  when(() => mockAuth.lastRoundSettings).thenReturn(null);
  when(() => mockAuth.currentUser).thenReturn(null);
  if (withStats) {
    final stats = createTestPlayerStats();
    when(() => mockApi.getPlayerStatsTyped()).thenAnswer((_) async => stats);
  }

  await pumpWithMaterialApp(
    tester,
    MainScreen(
      apiService: mockApi,
      authService: mockAuth,
      dailyQuestionService:
          mockDailyQuestionService ?? MockDailyQuestionService(),
    ),
  );
  await tester.pumpAndSettle();
}
