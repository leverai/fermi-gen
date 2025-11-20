## Test Fixtures Catalog

This document is the **single source of truth** for all reusable test fixtures in `@fermi-frontend`.
Whenever you add or modify fixtures, **update this file** as part of your feature request.

### Conventions

- **Location**: All fixtures live under `test/fixtures/`.
- **Usage**: Prefer using and extending existing fixtures instead of creating one-off data inside tests.
- **Docs**: Each fixture file listed below should have:
  - **Purpose**: What scenarios it supports.
  - **Key factories/helpers**: Function names and what they return.
  - **Dependencies**: Any services/models it relies on.

---

### `test/fixtures/game_snapshots.dart`

- **Purpose**: Factory functions for `GameSnapshot`-like structures to cover:
  - Lobby state
  - In-question states (including deadline timers)
  - Reveal states
  - Finished games (including review mode)
- **Key factories**:
  - `GameSnapshotFixtures.lobbyNotReady()` - Lobby waiting for players
  - `GameSnapshotFixtures.lobbyReady()` - Lobby ready to start
  - `GameSnapshotFixtures.questionN()` - Active question (not last)
  - `GameSnapshotFixtures.questionNFinished()` - Finished question (not last)
  - `GameSnapshotFixtures.questionLast()` - Last active question
  - `GameSnapshotFixtures.questionLastFinished()` - Last finished question
  - `GameSnapshotFixtures.gameFinished()` - Game finished (review mode)
  - `GameSnapshotFixtures.gameAborted()` - Aborted game
  - `GameSnapshotFixtures.multiPlayer()` - Multi-player scenario (3 players)
- **Dependencies**: `GameSnapshot`, `GameState`, `PlayerSummary` from `game_realtime.dart`
- **Used by**: Lobby controller/screen tests, question v2 controller/screen tests, realtime tests, integration flow tests.
- **Introduced by**: TEST_FEATURE_001

---

### `test/fixtures/question_data.dart`

- **Purpose**: Sample question payloads with:
  - Text, tags, categories, difficulties
  - Units and unit mappings (US/EU locales)
  - Correct answers and scoring metadata
- **Key factories**:
  - `QuestionDataFixtures.question1()` through `question5()` - Sample questions with different categories
  - `QuestionDataFixtures.unitlessQuestion()` - Question without units
  - `QuestionDataFixtures.correctAnswer1()` through `correctAnswer5()` - Correct answers for sample questions
  - `QuestionDataFixtures.questionUids()` - Generate list of question UIDs
  - `QuestionDataFixtures.revealPayload()` - Create reveal payload
  - Static constants: `sampleQuestion1-5`, `geographyTags`, `physicsTags`, etc.
  - Unit mappings: `usUnitOptions`, `euUnitOptions`, `usUnitAbbreviationToId`, etc.
- **Dependencies**: `RevealedQuestion`, `AnswerValue`, `RevealPayload` from `game_realtime.dart` and `answer_value.dart`
- **Used by**: `AnswerWidget`, `GameCard`, `QuestionWidget`, `QuestionScreenV2Controller`, integration flows.
- **Introduced by**: TEST_FEATURE_001

---

### `test/fixtures/player_data.dart`

- **Purpose**: Sample player data for:
  - Single-player and multi-player games
  - Host vs non-host
  - Different score distributions and ranks
- **Key factories**:
  - `PlayerDataFixtures.singlePlayer()` - Single player summary (host)
  - `PlayerDataFixtures.player()` - Generic player summary
  - `PlayerDataFixtures.threePlayers()` - Map of 3 players with different scores
  - `PlayerDataFixtures.fourPlayersWithTies()` - Map of 4 players with tied scores
  - `PlayerDataFixtures.playersWithInactive()` - Players including inactive ones
  - `PlayerDataFixtures.waitingPlayerState()` - PlayerState for waiting status
  - `PlayerDataFixtures.readyPlayerState()` - PlayerState for ready status
  - `PlayerDataFixtures.answerPlayerState()` - PlayerState for revealed answer
  - `PlayerDataFixtures.reviewPlayerState()` - PlayerState for review mode
  - `PlayerDataFixtures.submittedAnswers()` - Map of player IDs to submitted answers
  - `PlayerDataFixtures.playerScores()` - Map of player IDs to scores
  - `PlayerDataFixtures.cumulativeScores()` - Map of player IDs to cumulative scores
  - `PlayerDataFixtures.playerPercentiles()` - Map of player IDs to percentiles
  - `PlayerDataFixtures.progressAnswered()` - Map of player IDs to answered status
  - `PlayerDataFixtures.allPlayersAnswered()` - All players answered map
- **Dependencies**: `PlayerSummary` from `game_realtime.dart`, `PlayerState` from `player_widget.dart`, `AnswerValue` from `answer_value.dart`
- **Used by**: `PlayersRow`, `PlayerWidget`, `PlayerWidgetController`, confetti overlays, integration flows.
- **Introduced by**: TEST_FEATURE_001

---

### `test/helpers/mock_factories.dart`

- **Purpose**: Central place for reusable `mocktail` mocks and stub helpers.
- **Key mocks**:
  - `MockApiService` - Mock implementation of `ApiService` for stubbing API calls
  - `MockAuthService` - Mock implementation of `AuthService` for stubbing authentication
  - `MockGameRealtime` - Mock implementation of `GameRealtime` interface for stubbing realtime streams
  - `MockFirestoreGameRealtime` - Mock implementation of `FirestoreGameRealtime` concrete class
  - `registerFallbackValues()` - Registers fallback values for `mocktail`'s `any()` matchers (call in `setUpAll()`)
- **Usage**:
  ```dart
  setUpAll(() {
    registerFallbackValues();
  });

  test('example', () {
    final mockApi = MockApiService();
    when(() => mockApi.getGameConfig()).thenAnswer((_) async => {...});
  });
  ```
- **Guidelines**:
  - Follow `mocktail` usage guidance in `TESTING_GUIDELINES.md`.
  - Keep mocks generic and configurable; avoid tying them to a single test file.
  - Always call `registerFallbackValues()` in `setUpAll()` when using `any()` matchers.
- **Introduced by**: TEST_FEATURE_002

---

### `test/helpers/test_helpers.dart`

- **Purpose**: Generic helpers for pumping widgets, wrapping with `MaterialApp`, seeding providers/state, etc.
- **Key helpers**:
  - `pumpWithMaterialApp(tester, child, {locale})` - Pumps widget wrapped in MaterialApp with app theme extensions
  - `pumpWithScaffold(tester, child, {locale})` - Pumps widget wrapped in MaterialApp with Scaffold
  - `pumpAndSettleWithMaterialApp(tester, child, {locale, timeout})` - Pumps widget and waits for animations to settle
  - `pumpWithDelay(tester, child, {duration, locale})` - Pumps widget and waits for specific duration
  - `pumpUntil(tester, child, finder, {timeout, locale})` - Pumps until finder matches (useful for async operations)
- **Usage**:
  ```dart
  testWidgets('example', (tester) async {
    await pumpWithMaterialApp(tester, const MyWidget());
    expect(find.text('Hello'), findsOneWidget);
  });
  ```
- **Dependencies**: `AppTheme`, `AppFont` from theme extensions
- **Introduced by**: TEST_FEATURE_002

---

### `test/widget/screens/question_screen_v2/question_screen_v2_test_helpers.dart`

- **Purpose**: Specialized helpers for QuestionScreenV2 widget tests, including mock setup, stream configuration, and screen-specific utilities.
- **Key helpers**:
  - `setupQuestionScreenV2Tests()` - Registers fallback values for mocktail in setUpAll
  - `pumpQuestionScreen(tester, {gameId, realtime, questionCount, isHost, ...})` - Pumps QuestionScreenV2 with proper screen size (1080x2400) and theme
  - `createMockRealtimeWithStream({currentPlayerId, gameId, initialSnapshot})` - Creates MockGameRealtime with configured stream controller
  - `createSnapshotWithQuestion({questionUid, currentPlayerId, ...})` - Creates basic GameSnapshot using fixtures
  - `setupQuestionStreams(helper, gameId, questionIndex, {revealedQuestion, revealPayload, playersAnswers})` - Configures question-related streams
- **Key classes**:
  - `MockGameRealtimeWithStream` - Wrapper for MockGameRealtime with broadcast stream controller
- **Usage**:
  ```dart
  testWidgets('example', (tester) async {
    final mockHelper = createMockRealtimeWithStream(
      currentPlayerId: 'player_1',
      gameId: 'game_123',
    );

    final snapshot = createSnapshotWithQuestion(
      questionUid: 'question_1',
      currentPlayerId: 'player_1',
    );

    setupQuestionStreams(mockHelper, 'game_123', 0,
      revealedQuestion: QuestionDataFixtures.question1());

    await pumpQuestionScreen(tester,
      gameId: 'game_123',
      realtime: mockHelper.mock,
      questionCount: 5,
      isHost: true);

    mockHelper.streamController.add(snapshot);
    await tester.pumpAndSettle();
  });
  ```
- **Important Notes**:
  - Screen size is automatically set to 1080x2400 (required for QuestionScreenV2 layout)
  - Screen size is reset in tearDown via `addTearDown(() => tester.view.reset())`
  - All command methods on mock are stubbed to return successful futures
  - Stream methods return empty streams by default unless configured with `setupQuestionStreams()`
- **Dependencies**: `GameRealtime`, `GameSnapshot`, `GameSessionController`, fixtures
- **Introduced by**: TEST_FEATURE_032A

---

### `test/helpers/firebase_emulator_setup.dart`

- **Purpose**: Common setup code for integration tests using Firebase emulators.
- **Key helpers**:
  - `setupFirebaseEmulators({host, firestorePort, authPort})` - Configures Firebase services to use local emulators (call in `setUpAll()`)
  - `cleanupFirebaseEmulator()` - Cleans up emulator data between tests (signs out users)
  - `createTestUser({email, password, displayName})` - Creates and signs in a test user in Auth emulator
  - `signInTestUser({email, password})` - Signs in an existing test user
- **Usage**:
  ```dart
  void main() {
    setUpAll(() async {
      await setupFirebaseEmulators();
    });

    tearDown(() async {
      await cleanupFirebaseEmulator();
    });

    testWidgets('example', (tester) async {
      await createTestUser(email: 'test@example.com', password: 'pass123');
      // ... test code
    });
  }
  ```
- **Configuration**:
  - Default Firestore port: 8080
  - Default Auth port: 9099
  - Host auto-detects: '10.0.2.2' on Android, 'localhost' otherwise
- **Dependencies**: `firebase_core`, `firebase_auth`, `cloud_firestore`
- **Introduced by**: TEST_FEATURE_002

---

### Adding New Fixtures

When introducing new fixtures:

- **Place them** under `test/fixtures/` or `test/helpers/` as appropriate.
- **Document them** here with:
  - File name
  - Purpose
  - Key factories / helpers
  - Typical usage patterns
- **Link back** to the feature request that introduced them (in a short note).
