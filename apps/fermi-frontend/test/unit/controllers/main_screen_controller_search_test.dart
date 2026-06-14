import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';
import 'package:fermi_frontend/models/game_config.dart';

class MockApiService extends Mock implements ApiService {}

class MockAuthService extends Mock implements AuthService {}

class MockLocalSettingsService extends Mock implements LocalSettingsService {}

class FakeLastRoundSettings extends Fake implements LastRoundSettings {}

const _config = GameConfig(
  categories: [
    CategoryInfo(index: 0, name: 'GENERAL', slug: 'General', picture: ''),
    CategoryInfo(index: 1, name: 'PHYSICS', slug: 'Physics', picture: ''),
  ],
  difficulties: [
    DifficultyInfo(name: 'EASY', slug: 'Easy', picture: ''),
  ],
  ranks: [],
  smartSearchEnabled: true,
);

void main() {
  late MockApiService mockApi;
  late MockAuthService mockAuth;
  late MockLocalSettingsService mockLocal;
  late MainScreenController controller;

  setUpAll(() {
    registerFallbackValue(FakeLastRoundSettings());
  });

  setUp(() async {
    mockApi = MockApiService();
    mockAuth = MockAuthService();
    mockLocal = MockLocalSettingsService();
    when(() => mockAuth.lastRoundSettings).thenReturn(null);
    when(() => mockAuth.lastRoundSettings = any()).thenReturn(null);
    when(() => mockAuth.firebaseUid).thenReturn('uid-1');
    when(() => mockLocal.getRecentSearches(any()))
        .thenAnswer((_) async => const <String>[]);
    when(() => mockLocal.addRecentSearch(any(), any()))
        .thenAnswer((_) async {});
    controller = MainScreenController(
        api: mockApi, auth: mockAuth, localSettings: mockLocal);
    when(() => mockApi.getGameConfigTyped()).thenAnswer((_) async => _config);
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  group('Mutual exclusivity: search vs categories', () {
    test('setting a non-empty query clears + disables category selection', () {
      controller.selectCategoryIndices({0, 1});
      expect(controller.selectedCategoryIndices, {0, 1});

      controller.setSearchQuery('space scale');

      expect(controller.isSearching, isTrue);
      expect(controller.searchQuery, 'space scale');
      expect(controller.selectedCategoryIndices, isEmpty,
          reason: 'categories cleared when search becomes active');
    });

    test('selecting a category clears the active search', () {
      controller.setSearchQuery('space scale');
      expect(controller.isSearching, isTrue);

      controller.selectCategoryIndices({1});

      expect(controller.selectedCategoryIndices, {1});
      expect(controller.searchQuery, isNull);
      expect(controller.isSearching, isFalse);
      expect(controller.searchError, isNull);
    });

    test('clearing the query (empty string) re-enables categories', () {
      controller.setSearchQuery('space');
      expect(controller.isSearching, isTrue);

      controller.setSearchQuery('');

      expect(controller.isSearching, isFalse);
      expect(controller.searchQuery, isNull);
      // Categories may now be selected again.
      controller.selectCategoryIndices({0});
      expect(controller.selectedCategoryIndices, {0});
    });

    test('difficulty is unaffected by search/category switches', () {
      controller.selectDifficulty('EASY');
      controller.setSearchQuery('space');
      expect(controller.selectedDifficulty, 'EASY');

      controller.selectCategoryIndices({0});
      expect(controller.selectedDifficulty, 'EASY');
    });

    test('whitespace-only query does not activate search', () {
      controller.setSearchQuery('   ');
      expect(controller.isSearching, isFalse);
      expect(controller.searchQuery, isNull);
    });
  });

  group('createGame with search query', () {
    test(
        'passes the trimmed query to the API and saves it to recents on '
        'success', () async {
      controller.setSearchQuery('  space scale  ');
      when(() => mockApi.createGame(
            categories: any(named: 'categories'),
            difficulty: any(named: 'difficulty'),
            nQuestions: any(named: 'nQuestions'),
            searchQuery: 'space scale',
          )).thenAnswer((_) async => 'game-123');

      final id = await controller.createGame();

      expect(id, 'game-123');
      verify(() => mockApi.createGame(
            categories: any(named: 'categories'),
            difficulty: any(named: 'difficulty'),
            nQuestions: any(named: 'nQuestions'),
            searchQuery: 'space scale',
          )).called(1);
      // Recents saved with the raw trimmed query, keyed by uid.
      verify(() => mockLocal.addRecentSearch('uid-1', 'space scale')).called(1);
    });

    test('does NOT save to recents when no search query is active', () async {
      controller.selectCategoryIndices({0});
      when(() => mockApi.createGame(
            categories: any(named: 'categories'),
            difficulty: any(named: 'difficulty'),
            nQuestions: any(named: 'nQuestions'),
            searchQuery: null,
          )).thenAnswer((_) async => 'game-xyz');

      await controller.createGame();

      verifyNever(() => mockLocal.addRecentSearch(any(), any()));
    });
  });

  group('search_no_results (HTTP 422) handling', () {
    test(
        'surfaces the inline message, keeps the query, and does NOT save to '
        'recents', () async {
      controller.setSearchQuery('asdfqwer');
      when(() => mockApi.createGame(
            categories: any(named: 'categories'),
            difficulty: any(named: 'difficulty'),
            nQuestions: any(named: 'nQuestions'),
            searchQuery: 'asdfqwer',
          )).thenThrow(SearchNoResultsException(
        query: 'asdfqwer',
        message: "No questions match 'asdfqwer' — try a broader search.",
      ));

      await expectLater(
        controller.createGame(),
        throwsA(isA<SearchNoResultsException>()),
      );

      // Inline error set; query preserved; generic errorMessage NOT set.
      expect(controller.searchError,
          "No questions match 'asdfqwer' — try a broader search.");
      expect(controller.searchQuery, 'asdfqwer');
      expect(controller.errorMessage, isNull);
      // Not added to recents.
      verifyNever(() => mockLocal.addRecentSearch(any(), any()));
      expect(controller.isSubmitting, isFalse);
    });

    test('a generic failure (e.g. 503) sets errorMessage, not searchError',
        () async {
      controller.setSearchQuery('space');
      when(() => mockApi.createGame(
            categories: any(named: 'categories'),
            difficulty: any(named: 'difficulty'),
            nQuestions: any(named: 'nQuestions'),
            searchQuery: 'space',
          )).thenThrow(Exception('Failed to create game: transient'));

      await expectLater(controller.createGame(), throwsA(isA<Exception>()));

      expect(controller.searchError, isNull);
      expect(controller.errorMessage, isNotNull);
      // Generic failures do not save to recents either.
      verifyNever(() => mockLocal.addRecentSearch(any(), any()));
    });

    test('editing the query clears a previous inline searchError', () {
      controller.searchError = 'old error';
      controller.setSearchQuery('new query');
      expect(controller.searchError, isNull);
    });
  });
}
