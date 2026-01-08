import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import '../../../helpers/mock_factories.dart';

/// Unit tests for ApiService authentication and configuration methods.
///
/// Tests cover:
/// - Authentication: token handling, refresh logic, 401 responses
/// - Game Config: fetching and parsing configuration
/// - Player Stats: fetching and parsing player statistics
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

  group('Authentication', () {
    test('should include access token in requests', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token-123');
        return http.Response('{"resource_id": "game-123"}', 200);
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.createGame();

      // ASSERT - verified by expect in MockClient callback
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
      final result = await apiService.createGame();

      // ASSERT
      verify(() => mockAuthService.refreshAccessToken()).called(1);
      expect(result, 'game-123');
      expect(callCount, 2); // Original + retry
    });

    test('should retry request after token refresh', () async {
      // ARRANGE
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          expect(request.headers['Authorization'], 'Bearer old-token');
          return http.Response('{"detail": "Unauthorized"}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-token');
        return http.Response('{"resource_id": "game-123"}', 200);
      });

      int tokenCallCount2 = 0;
      when(() => mockAuthService.accessToken).thenAnswer((_) {
        tokenCallCount2++;
        return tokenCallCount2 == 1 ? 'old-token' : 'new-token';
      });
      when(() => mockAuthService.refreshAccessToken())
          .thenAnswer((_) async => true);

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      await apiService.createGame();

      // ASSERT
      expect(callCount, 2);
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
        () => apiService.createGame(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('not authorized'),
        )),
      );
    });

    test('should throw exception when refresh fails', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response('{"detail": "Unauthorized"}', 401);
      });

      when(() => mockAuthService.refreshAccessToken())
          .thenAnswer((_) async => false);

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
          contains('Failed to create game'),
        )),
      );
    });
  });

  group('Game Config', () {
    test('should fetch game config successfully', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/game/config');
        expect(request.headers['Accept'], 'application/json');
        return http.Response(
          jsonEncode({
            'categories': [
              {
                'index': 0,
                'name': 'GEOGRAPHY',
                'slug': 'Geography',
                'theme': {'primary': 'FF0000FF'},
                'picture': 'https://example.com/geo.jpg'
              }
            ],
            'difficulties': [
              {
                'name': 'EASY',
                'slug': 'Easy',
                'picture': 'https://example.com/easy.svg'
              }
            ],
          }),
          200,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      final config = await apiService.getGameConfig();

      // ASSERT
      expect(config, isA<Map<String, dynamic>>());
      expect(config['categories'], isNotEmpty);
      expect(config['difficulties'], isNotEmpty);
    });

    test('should parse game config JSON correctly', () async {
      // ARRANGE
      final json = {
        'categories': [
          {
            'index': 0,
            'name': 'GEOGRAPHY',
            'slug': 'Geography',
            'theme': {'primary': 'FF0000FF', 'secondary': 'FF00FF00'},
            'picture': 'https://example.com/geo.jpg'
          }
        ],
        'difficulties': [
          {
            'name': 'EASY',
            'slug': 'Easy',
            'picture': 'https://example.com/easy.svg'
          }
        ]
      };

      // ACT
      final config = GameConfig.fromJson(json);

      // ASSERT
      expect(config.categories.length, 1);
      expect(config.categories[0].name, 'GEOGRAPHY');
      expect(config.categories[0].slug, 'Geography');
      expect(config.difficulties.length, 1);
      expect(config.difficulties[0].name, 'EASY');
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
        () => apiService.getGameConfig(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Network error'),
        )),
      );
    });

    test('should handle server errors', () async {
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
        () => apiService.getGameConfig(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get game config'),
        )),
      );
    });
  });

  group('Player Stats', () {
    test('should fetch player stats successfully', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/game/get_player_stats');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body, isEmpty); // No player_id in request body anymore
        return http.Response(
          jsonEncode({
            'player_id': 'player-123',
            'stats': {
              'total_party_games': 10,
              'total_daily_guesses': 5,
              'average_percentile': 75,
              'level': 1
            }
          }),
          200,
        );
      });

      final apiService = ApiService(
        authService: mockAuthService,
        client: mockClient,
        apiBaseUrl: 'http://test-api',
      );

      // ACT
      final stats = await apiService.getPlayerStats();

      // ASSERT
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['player_id'], 'player-123');
    });

    test('should parse player stats JSON correctly', () async {
      // ARRANGE
      final json = {
        'player_id': 'player-123',
        'stats': {
          'total_party_games': 42,
          'total_daily_guesses': 15,
          'average_percentile': 75,
          'level': 1
        }
      };

      // ACT
      final stats = PlayerStatsResponse.fromJson(json);

      // ASSERT
      expect(stats.playerId, 'player-123');
      expect(stats.stats.totalPartyGames, 42);
      expect(stats.stats.totalDailyGuesses, 15);
      expect(stats.stats.averagePercentile, 75);
      expect(stats.stats.level, 1);
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
        () => apiService.getPlayerStats(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Network error'),
        )),
      );
    });

    test('should handle server errors', () async {
      // ARRANGE
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Player not found'}),
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
        () => apiService.getPlayerStats(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get player stats'),
        )),
      );
    });
  });
}
