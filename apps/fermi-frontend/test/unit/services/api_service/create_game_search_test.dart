import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/api_service.dart';
import '../../../helpers/mock_factories.dart';

/// Unit tests for the smart-search additions to [ApiService.createGame]:
/// - the request carries `search_query` and nulls `categories`
/// - a 422 `search_no_results` becomes a [SearchNoResultsException]
/// - other failures (e.g. 503) fall through to the generic exception
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

  group('422 search_no_results handling', () {
    test('throws SearchNoResultsException with the server message', () async {
      final client = MockClient((request) async {
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
        buildService(client).createGame(searchQuery: 'asdfqwer'),
        throwsA(
          isA<SearchNoResultsException>()
              .having((e) => e.query, 'query', 'asdfqwer')
              .having((e) => e.message, 'message', contains('broader')),
        ),
      );
    });

    test('branches on detail.code, not message text', () async {
      // A 422 whose detail is NOT the search_no_results code should fall
      // through to the generic exception (e.g. a validation error).
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'String too short'}),
          422,
        );
      });

      await expectLater(
        buildService(client).createGame(searchQuery: 'x'),
        throwsA(
          isA<Exception>()
              .having((e) => e.toString(), 'msg', contains('Failed to create')),
        ),
      );
    });

    test('does not treat a 422 as search_no_results when no search was sent',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {'code': 'search_no_results', 'message': 'x'}
          }),
          422,
        );
      });

      await expectLater(
        buildService(client).createGame(categories: ['GENERAL']),
        throwsA(isA<Exception>()),
      );
      // Specifically NOT a SearchNoResultsException.
      await expectLater(
        buildService(client).createGame(categories: ['GENERAL']),
        throwsA(isNot(isA<SearchNoResultsException>())),
      );
    });
  });

  group('503 transient handling falls through to generic', () {
    test('503 throws a generic Exception, not SearchNoResultsException',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': "Couldn't build your search game, try again"}),
          503,
        );
      });

      await expectLater(
        buildService(client).createGame(searchQuery: 'space'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SearchNoResultsException>()),
          ),
        ),
      );
    });
  });
}
