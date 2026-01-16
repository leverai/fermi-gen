import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/api_service.dart';
import '../../../helpers/mock_factories.dart';

/// Unit tests for ApiService.addBots method.
///
/// Tests cover:
/// - Successful bot addition with proper request formation
/// - Error handling for server and network failures
/// - Authentication token handling
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

  group('addBots', () {
    test('should send correct request with game ID and bot IDs', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/game/add_bots');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test-token-123');
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body);
        expect(body['resource_id'], 'game-123');
        expect(body['bot_ids'], ['bot-gemini1', 'bot-gemini2']);

        return http.Response('{"resource_id": "game-123"}', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.addBots(
        gameId: 'game-123',
        botIds: ['bot-gemini1', 'bot-gemini2'],
      );

      // ASSERT - verified by expect in MockClient callback
    });

    test('should handle successful response (200)', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response('{"resource_id": "game-123"}', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT - should not throw
      await apiService.addBots(
        gameId: 'game-123',
        botIds: ['bot-gemini1'],
      );
    });

    test('should handle server error (400)', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Too many players'}),
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
        () => apiService.addBots(
          gameId: 'game-123',
          botIds: ['bot-gemini1', 'bot-gemini2', 'bot-gemini3'],
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to add bots: Too many players'),
        )),
      );
    });

    test('should handle server error (500)', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Internal server error'}),
          500,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.addBots(
          gameId: 'game-123',
          botIds: ['bot-gemini1'],
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to add bots'),
        )),
      );
    });

    test('should handle network errors', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.addBots(
          gameId: 'game-123',
          botIds: ['bot-gemini1', 'bot-gemini2'],
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Network error: Please check your connection.'),
        )),
      );
    });

    test('should throw exception when unauthorized', () async {
      // ARRANGE
      when(() => mockAuthService.accessToken).thenReturn(null);

      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT & ASSERT
      expect(
        () => apiService.addBots(
          gameId: 'game-123',
          botIds: ['bot-gemini1'],
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not authorized'),
        )),
      );
    });

    test('should refresh token on 401 response', () async {
      // ARRANGE
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('{"detail": "Unauthorized"}', 401);
        }
        return http.Response('{"resource_id": "game-123"}', 200);
      });

      int tokenCallCount = 0;
      when(() => mockAuthService.refreshAccessToken())
          .thenAnswer((_) async => true);
      when(() => mockAuthService.accessToken).thenAnswer((_) {
        tokenCallCount++;
        return tokenCallCount == 1 ? 'test-token-123' : 'refreshed-token-456';
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.addBots(
        gameId: 'game-123',
        botIds: ['bot-gemini1', 'bot-gemini2'],
      );

      // ASSERT
      verify(() => mockAuthService.refreshAccessToken()).called(1);
      expect(callCount, 2); // Original + retry
    });
  });
}
