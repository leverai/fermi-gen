import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fermi_frontend/services/auth_service.dart';

/// Mock implementations for FirebaseAuth and related classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockHttpClient extends Mock implements http.Client {}

class MockResponse extends Mock implements http.Response {}

/// Fake URI for use with any() matchers
class FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    // Register fallback values for any() matchers
    registerFallbackValue(FakeUri());
  });

  group('AuthService - Token Exchange', () {
    late MockFirebaseAuth mockAuth;
    late MockHttpClient mockHttpClient;
    late MockUser mockUser;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockHttpClient = MockHttpClient();
      mockUser = MockUser();
      authService = AuthService(
        auth: mockAuth,
        httpClient: mockHttpClient,
      );
    });

    test('should exchange Firebase token for access token', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';
      const accessToken = 'access-token-456';
      final responseBody = jsonEncode({
        'access_token': accessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
          'display_name': 'Test User',
          'picture': 'https://example.com/pic.jpg',
        },
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      final result = await authService.exchangeToken();

      // Assert
      expect(result, true);
      verify(() => mockUser.getIdToken()).called(1);
      verify(() => mockHttpClient.post(
            any(that: predicate((Uri uri) => uri.path.endsWith('/auth/token'))),
            headers: any(
              named: 'headers',
              that: predicate((Map<String, String> headers) =>
                  headers['Authorization'] == 'Bearer $firebaseIdToken' &&
                  headers['Accept'] == 'application/json'),
            ),
          )).called(1);
    });

    test('should store access token', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';
      const accessToken = 'access-token-456';
      final responseBody = jsonEncode({
        'access_token': accessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
        },
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      await authService.exchangeToken();

      // Assert
      expect(authService.accessToken, accessToken);
    });

    test('should parse user object from response', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';
      const accessToken = 'access-token-456';
      final responseBody = jsonEncode({
        'access_token': accessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
          'display_name': 'Test User',
          'picture': 'https://example.com/pic.jpg',
        },
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      await authService.exchangeToken();

      // Assert
      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser?.firebaseUid, 'uid-123');
      expect(authService.currentUser?.email, 'test@example.com');
      expect(authService.currentUser?.displayName, 'Test User');
      expect(authService.currentUser?.picture, 'https://example.com/pic.jpg');
    });

    test('should store firebase UID', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';
      const accessToken = 'access-token-456';
      final responseBody = jsonEncode({
        'access_token': accessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
        },
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      await authService.exchangeToken();

      // Assert
      expect(authService.firebaseUid, 'uid-123');
    });

    test('should store locale from user object', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';
      const accessToken = 'access-token-456';
      final responseBody = jsonEncode({
        'access_token': accessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
          'locale': 'EU',
        },
      });

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      await authService.exchangeToken();

      // Assert
      expect(authService.locale, 'EU');
    });

    test('should return false on exchange failure', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';
      final responseBody = jsonEncode({'detail': 'Invalid token'});

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 401));

      // Act
      final result = await authService.exchangeToken();

      // Assert
      expect(result, false);
      expect(authService.accessToken, isNull);
    });

    test('should handle network errors', () async {
      // Arrange
      const firebaseIdToken = 'firebase-id-token-123';

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await authService.exchangeToken();

      // Assert
      expect(result, false);
      expect(authService.accessToken, isNull);
    });

    test('should handle invalid token', () async {
      // Arrange
      when(() => mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await authService.exchangeToken();

      // Assert
      expect(result, false);
      expect(authService.accessToken, isNull);
      verifyNever(
          () => mockHttpClient.post(any(), headers: any(named: 'headers')));
    });
  });

  group('AuthService - Token Refresh', () {
    late MockFirebaseAuth mockAuth;
    late MockHttpClient mockHttpClient;
    late MockUser mockUser;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockHttpClient = MockHttpClient();
      mockUser = MockUser();
      authService = AuthService(
        auth: mockAuth,
        httpClient: mockHttpClient,
      );
    });

    test('should refresh access token successfully', () async {
      // Arrange
      const oldAccessToken = 'old-token-123';
      const newAccessToken = 'new-token-456';
      authService.accessToken = oldAccessToken;

      final responseBody = jsonEncode({
        'access_token': newAccessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
        },
      });

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      final result = await authService.refreshAccessToken();

      // Assert
      expect(result, true);
      verify(() => mockHttpClient.post(
            any(
                that:
                    predicate((Uri uri) => uri.path.endsWith('/auth/refresh'))),
            headers: any(
              named: 'headers',
              that: predicate((Map<String, String> headers) =>
                  headers['Authorization'] == 'Bearer $oldAccessToken' &&
                  headers['Accept'] == 'application/json'),
            ),
          )).called(1);
    });

    test('should update access token', () async {
      // Arrange
      const oldAccessToken = 'old-token-123';
      const newAccessToken = 'new-token-456';
      authService.accessToken = oldAccessToken;

      final responseBody = jsonEncode({
        'access_token': newAccessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
        },
      });

      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      await authService.refreshAccessToken();

      // Assert
      expect(authService.accessToken, newAccessToken);
    });

    test('should update user object', () async {
      // Arrange
      const oldAccessToken = 'old-token-123';
      const newAccessToken = 'new-token-456';
      authService.accessToken = oldAccessToken;

      final responseBody = jsonEncode({
        'access_token': newAccessToken,
        'user': {
          'firebase_uid': 'uid-456',
          'email': 'updated@example.com',
          'display_name': 'Updated User',
          'locale': 'US',
        },
      });

      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 200));

      // Act
      await authService.refreshAccessToken();

      // Assert
      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser?.firebaseUid, 'uid-456');
      expect(authService.currentUser?.email, 'updated@example.com');
      expect(authService.currentUser?.displayName, 'Updated User');
      expect(authService.firebaseUid, 'uid-456');
      expect(authService.locale, 'US');
    });

    test('should fallback to exchange on 401', () async {
      // Arrange
      const oldAccessToken = 'old-token-123';
      const firebaseIdToken = 'firebase-id-token-789';
      const newAccessToken = 'new-token-from-exchange';
      authService.accessToken = oldAccessToken;

      final refreshResponseBody = jsonEncode({'detail': 'Token expired'});
      final exchangeResponseBody = jsonEncode({
        'access_token': newAccessToken,
        'user': {
          'firebase_uid': 'uid-123',
          'email': 'test@example.com',
        },
      });

      // Mock refresh returning 401
      when(() => mockHttpClient.post(
            any(
                that:
                    predicate((Uri uri) => uri.path.endsWith('/auth/refresh'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(refreshResponseBody, 401));

      // Mock exchange succeeding
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken())
          .thenAnswer((_) async => firebaseIdToken);
      when(() => mockHttpClient.post(
            any(that: predicate((Uri uri) => uri.path.endsWith('/auth/token'))),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(exchangeResponseBody, 200));

      // Act
      final result = await authService.refreshAccessToken();

      // Assert
      expect(result, true);
      expect(authService.accessToken, newAccessToken);
      verify(() => mockHttpClient.post(
            any(
                that:
                    predicate((Uri uri) => uri.path.endsWith('/auth/refresh'))),
            headers: any(named: 'headers'),
          )).called(1);
      verify(() => mockUser.getIdToken()).called(1);
      verify(() => mockHttpClient.post(
            any(that: predicate((Uri uri) => uri.path.endsWith('/auth/token'))),
            headers: any(named: 'headers'),
          )).called(1);
    });

    test('should return false on refresh failure', () async {
      // Arrange
      const oldAccessToken = 'old-token-123';
      authService.accessToken = oldAccessToken;

      final responseBody = jsonEncode({'detail': 'Server error'});

      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responseBody, 500));

      // Act
      final result = await authService.refreshAccessToken();

      // Assert
      expect(result, false);
      expect(authService.accessToken,
          oldAccessToken); // Token unchanged on failure
    });

    test('should handle network errors', () async {
      // Arrange
      const oldAccessToken = 'old-token-123';
      authService.accessToken = oldAccessToken;

      when(() => mockHttpClient.post(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await authService.refreshAccessToken();

      // Assert
      expect(result, false);
      expect(
          authService.accessToken, oldAccessToken); // Token unchanged on error
    });
  });

  group('AuthService - State Management', () {
    late MockFirebaseAuth mockAuth;
    late MockHttpClient mockHttpClient;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockHttpClient = MockHttpClient();
      authService = AuthService(
        auth: mockAuth,
        httpClient: mockHttpClient,
      );
    });

    test('should store last round settings', () {
      // Arrange
      const settings = LastRoundSettings(
        categories: ['PLANET_EARTH'],
        difficulty: 'MEDIUM',
      );

      // Act
      authService.lastRoundSettings = settings;

      // Assert
      expect(authService.lastRoundSettings, isNotNull);
      expect(authService.lastRoundSettings?.categories, ['PLANET_EARTH']);
      expect(authService.lastRoundSettings?.difficulty, 'MEDIUM');
    });

    test('should clear last round settings', () {
      // Arrange
      const settings = LastRoundSettings(
        categories: ['PLANET_EARTH'],
        difficulty: 'MEDIUM',
      );
      authService.lastRoundSettings = settings;

      // Act
      authService.lastRoundSettings = null;

      // Assert
      expect(authService.lastRoundSettings, isNull);
    });

    test('should track shouldRefreshStats flag', () {
      // Arrange
      expect(authService.shouldRefreshStats, false);

      // Act
      authService.shouldRefreshStats = true;

      // Assert
      expect(authService.shouldRefreshStats, true);

      // Act
      authService.shouldRefreshStats = false;

      // Assert
      expect(authService.shouldRefreshStats, false);
    });
  });
}
