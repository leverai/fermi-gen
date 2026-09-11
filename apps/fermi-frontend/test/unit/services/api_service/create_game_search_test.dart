import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/api_service.dart';
import '../../../helpers/mock_factories.dart';

/// Unit tests for the smart-search behaviour of [ApiService].
///
/// The search now runs at GAME START, not at create:
/// - [ApiService.createGame] only shapes the request (carries `search_query`,
///   nulls `categories`). It does NOT parse search failures: /game/create no
///   longer returns the 422 `search_no_results` nor the 503 embed failure, so
///   every non-200 is a generic failure.
/// - [ApiService.startGame] parses the search failures into typed exceptions:
///   * legacy 422 `detail.code == 'search_no_results'` -> [SearchNoResultsException]
///   * 503 `detail.code == 'search_insufficient_questions'`
///     -> [SearchInsufficientQuestionsException]
///   * 503 `detail.code == 'search_embedding_error'` -> [SearchEmbeddingException]
///   * anything else -> generic [Exception]
void main() {
  late MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockAuthService = MockAuthService();
    when(() => mockAuthService.accessToken).thenReturn('test-token-123');
    when(() => mockAuthService.refreshAccessToken())
        .thenAnswer((_) async => false);
    when(() => mockAuthService.shouldRefreshToken()).thenReturn(false);
  });

  ApiService buildService(MockClient client) => ApiService(
        authService: mockAuthService,
        client: client,
        apiBaseUrl: 'http://test-api',
      );

  group('createGame request shaping', () {
    test('sends search_query and nulls categories when searching', () async {
      Map<String, dynamic>? sentSettings;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentSettings = body['question_round_settings'] as Map<String, dynamic>;
        return http.Response('{"resource_id": "game-1"}', 200);
      });

      await buildService(client).createGame(
        categories: ['GENERAL'],
        difficulty: 'EASY',
        nQuestions: 6,
        searchQuery: '  space scale  ',
      );

      expect(sentSettings, isNotNull);
      expect(sentSettings!['search_query'], 'space scale');
      expect(sentSettings!['categories'], isNull,
          reason: 'categories dropped when a search is present');
      expect(sentSettings!['difficulty'], 'EASY');
    });

    test('omits search_query and keeps categories when not searching',
        () async {
      Map<String, dynamic>? sentSettings;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentSettings = body['question_round_settings'] as Map<String, dynamic>;
        return http.Response('{"resource_id": "game-1"}', 200);
      });

      await buildService(client).createGame(
        categories: ['GENERAL'],
        difficulty: 'EASY',
        nQuestions: 6,
      );

      expect(sentSettings!.containsKey('search_query'), isFalse);
      expect(sentSettings!['categories'], ['GENERAL']);
    });
  });

  group('createGame no longer parses search failures', () {
    test('a 422 search_no_results body is a GENERIC failure at create',
        () async {
      // The search runs at start, so even a body that *looks* like
      // search_no_results must NOT become a SearchNoResultsException here.
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {'code': 'search_no_results', 'message': 'x'}
          }),
          422,
        );
      });

      await expectLater(
        buildService(client).createGame(searchQuery: 'asdfqwer'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SearchNoResultsException>()),
            isNot(isA<SearchInsufficientQuestionsException>()),
            isNot(isA<SearchEmbeddingException>()),
          ),
        ),
      );
    });

    test('a 503 embed-failure body is a GENERIC failure at create', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'search_embedding_error',
              'message': "Couldn't build your search game, try again",
            }
          }),
          503,
        );
      });

      await expectLater(
        buildService(client).createGame(searchQuery: 'space'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SearchNoResultsException>()),
            isNot(isA<SearchEmbeddingException>()),
          ),
        ),
      );
    });
  });

  group('startGame: 422 search_no_results', () {
    test('throws SearchNoResultsException with the server message', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/game/start');
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'search_no_results',
              'message':
                  "No questions match 'asdfqwer' — try a broader or different search.",
            }
          }),
          422,
          // Server returns UTF-8 (message contains an em-dash); declare it so
          // the parser decodes bodyBytes correctly.
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        throwsA(
          isA<SearchNoResultsException>()
              .having((e) => e.message, 'message', contains('broader')),
        ),
      );
    });

    test('branches on detail.code, not message text (other 422 is generic)',
        () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'String too short'}), 422);
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SearchNoResultsException>()),
          ),
        ),
      );
    });
  });

  group('startGame: 503 insufficient questions', () {
    test(
        'throws SearchInsufficientQuestionsException and preserves the server message',
        () async {
      const serverMessage =
          'Not enough questions are available to start this game.';
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'search_insufficient_questions',
              'message': serverMessage,
            }
          }),
          503,
        );
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        throwsA(
          isA<SearchInsufficientQuestionsException>()
              .having((e) => e.message, 'message', serverMessage),
        ),
      );
    });
  });

  group('startGame: 503 embed failure', () {
    test('throws SearchEmbeddingException on the search_embedding_error code',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'search_embedding_error',
              'message': "Couldn't build your search game, try again",
            }
          }),
          503,
        );
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        throwsA(
          isA<SearchEmbeddingException>()
              .having((e) => e.message, 'message', contains('try again')),
        ),
      );
    });

    test('a different 503 (legacy "No questions available") is generic',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'No questions available to start the game'}),
          503,
        );
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SearchEmbeddingException>()),
            isNot(isA<SearchInsufficientQuestionsException>()),
            isNot(isA<SearchNoResultsException>()),
          ),
        ),
      );
    });
  });

  group('startGame: success and generic failures', () {
    test('returns normally (no throw) on 200', () async {
      final client = MockClient((request) async {
        return http.Response('{"resource_id": "game-1"}', 200);
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        completes,
      );
    });

    test('a 500 is a generic Exception, not a search exception', () async {
      final client = MockClient((request) async {
        return http.Response('boom', 500);
      });

      await expectLater(
        buildService(client).startGame(gameId: 'game-1'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SearchNoResultsException>()),
            isNot(isA<SearchInsufficientQuestionsException>()),
            isNot(isA<SearchEmbeddingException>()),
          ),
        ),
      );
    });
  });
}
