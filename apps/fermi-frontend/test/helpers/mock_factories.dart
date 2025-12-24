import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/services/firestore_game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';

/// Mock implementation of [ApiService] for unit and widget tests.
///
/// Use [MockApiService] with `mocktail`'s `when()` to stub method responses.
/// Example:
/// ```dart
/// final mockApi = MockApiService();
/// when(() => mockApi.getGameConfig()).thenAnswer((_) async => {...});
/// ```
class MockApiService extends Mock implements ApiService {}

/// Mock implementation of [AuthService] for unit and widget tests.
///
/// Use [MockAuthService] with `mocktail`'s `when()` to stub method responses.
/// Example:
/// ```dart
/// final mockAuth = MockAuthService();
/// when(() => mockAuth.accessToken).thenReturn('test-token');
/// when(() => mockAuth.exchangeToken()).thenAnswer((_) async => true);
/// ```
class MockAuthService extends Mock implements AuthService {}

/// Mock implementation of [GameRealtime] interface for unit and widget tests.
///
/// Use [MockGameRealtime] with `mocktail`'s `when()` to stub stream responses.
/// Example:
/// ```dart
/// final mockRealtime = MockGameRealtime();
/// when(() => mockRealtime.currentPlayerId).thenReturn('player-123');
/// when(() => mockRealtime.watchGame(any())).thenAnswer(
///   (_) => Stream.value(gameSnapshot),
/// );
/// ```
class MockGameRealtime extends Mock implements GameRealtime {}

/// Mock implementation of [FirestoreGameRealtime] for unit and widget tests.
///
/// Use [MockFirestoreGameRealtime] with `mocktail`'s `when()` to stub method responses.
/// Note: This mocks the concrete class, but in most cases you should prefer
/// mocking the [GameRealtime] interface instead.
class MockFirestoreGameRealtime extends Mock implements FirestoreGameRealtime {}

/// Mock implementation of [DailyQuestionService] for unit and widget tests.
class MockDailyQuestionService extends Mock implements DailyQuestionService {}

/// Fallback value registrations for mocktail.
///
/// Call this function in your test's `setUpAll()` or `main()` to register
/// fallback values for types that may be used with `any()` matchers.
///
/// Example:
/// ```dart
/// void main() {
///   setUpAll(() {
///     registerFallbackValues();
///   });
///   // ... tests
/// }
/// ```
void registerFallbackValues() {
  registerFallbackValue(const AnswerValue(
    number: 0,
    orderOfMagnitude: '',
    unit: '',
  ));
}
