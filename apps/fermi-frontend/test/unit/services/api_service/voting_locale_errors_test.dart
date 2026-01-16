import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/api_service.dart';
import '../../../helpers/mock_factories.dart';

/// Unit tests for ApiService voting, locale, and error handling methods.
///
/// Tests cover:
/// - Question Voting: upvote/downvote and toggle behavior
/// - User Locale: setting and updating locale preferences
/// - Error Handling: JSON/non-JSON errors, message extraction, truncation
///
/// Part of TEST_FEATURE_013 – ApiService unit tests
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
  });

  group('Question Voting', () {
    test('should upvote question', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/question/upvote');
        final body = jsonDecode(request.body);
        expect(body['resource_id'], 'question-123');
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.upvoteQuestion(questionUid: 'question-123');

      // ASSERT - verified by MockClient expectations
    });

    test('should de-upvote question (via downvote toggle)', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/question/downvote');
        final body = jsonDecode(request.body);
        expect(body['resource_id'], 'question-123');
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.deUpvoteQuestion(questionUid: 'question-123');

      // ASSERT - verified by MockClient expectations
    });

    test('should downvote question', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/question/downvote');
        final body = jsonDecode(request.body);
        expect(body['resource_id'], 'question-456');
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.downvoteQuestion(questionUid: 'question-456');

      // ASSERT - verified by MockClient expectations
    });

    test('should de-downvote question (via upvote toggle)', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/question/upvote');
        final body = jsonDecode(request.body);
        expect(body['resource_id'], 'question-456');
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.deDownvoteQuestion(questionUid: 'question-456');

      // ASSERT - verified by MockClient expectations
    });

    test('should handle voting errors', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Question not found'}),
          404,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.upvoteQuestion(questionUid: 'invalid-id'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Request /question/upvote failed'),
        )),
      );
    });
  });

  group('User Locale', () {
    test('should set user locale', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/user/set_locale');
        final body = jsonDecode(request.body);
        expect(body['locale'], 'en-US');
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.setUserLocale(locale: 'en-US');

      // ASSERT - verified by MockClient expectations
    });

    test('should update auth service locale', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.setUserLocale(locale: 'en-EU');

      // ASSERT
      verify(() => mockAuthService.locale = 'en-EU').called(1);
    });

    test('should handle locale errors', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid locale'}),
          400,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.setUserLocale(locale: 'invalid'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to set locale'),
        )),
      );
    });
  });

  group('Error Handling', () {
    test('should extract error message from JSON detail', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Specific error message'}),
          400,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      try {
        await apiService.createGame();
        fail('Should have thrown exception');
      } catch (e) {
        expect(e.toString(), contains('Specific error message'));
      }
    });

    test('should handle non-JSON error responses', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          '<html><body>Internal Server Error</body></html>',
          500,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      try {
        await apiService.startGame(gameId: 'game-123');
        fail('Should have thrown exception');
      } catch (e) {
        // Should extract some text from HTML or show status code
        expect(e, isA<Exception>());
        expect(
          e.toString(),
          anyOf(
            contains('html'),
            contains('Internal Server Error'),
            contains('500'),
          ),
        );
      }
    });

    test('should handle empty error responses', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response('', 500);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      try {
        await apiService.startGame(gameId: 'game-123');
        fail('Should have thrown exception');
      } catch (e) {
        expect(e, isA<Exception>());
        // Should include HTTP status code when body is empty
        expect(e.toString(), contains('500'));
      }
    });

    test('should trim long error messages', () async {
      // ARRANGE
      final longMessage = 'Error: ${'x' * 500}';
      final mockClient = MockClient((request) async {
        return http.Response(longMessage, 400);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      try {
        await apiService.startGame(gameId: 'game-123');
        fail('Should have thrown exception');
      } catch (e) {
        final errorMsg = e.toString();
        // Error message should be trimmed (max 200 chars from body + exception wrapper)
        expect(errorMsg.length, lessThan(300));
      }
    });

    test('should handle network timeout', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection timeout');
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.createGame(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Network error'),
        )),
      );
    });

    test('should handle connection refused', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.getGameConfig(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Network error'),
        )),
      );
    });

    test('should handle malformed JSON in success response', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.getGameConfig(),
        throwsA(isA<FormatException>()),
      );
    });

    test('should handle missing resource_id in response', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response('{"other_field": "value"}', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      // Should throw when trying to access resource_id as String
      expect(
        () => apiService.createGame(),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
