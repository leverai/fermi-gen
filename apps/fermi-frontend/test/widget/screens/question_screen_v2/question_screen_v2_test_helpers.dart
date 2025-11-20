import 'dart:async';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/services/game_session.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import '../../../helpers/test_helpers.dart';
import '../../../helpers/mock_factories.dart';
import '../../../fixtures/game_snapshots.dart';

/// Shared test setup for QuestionScreenV2 widget tests
void setupQuestionScreenV2Tests() {
  setUpAll(() {
    registerFallbackValues();
  });
}

/// Helper to pump QuestionScreenV2 with default test setup
Future<void> pumpQuestionScreen(
  WidgetTester tester, {
  required String gameId,
  required GameRealtime realtime,
  required int questionCount,
  required bool isHost,
  GameSessionController? session,
  List<PlayerState> initialPlayers = const [],
  bool showLeaveButton = true,
}) async {
  // Set a larger screen size for QuestionScreenV2 tests
  // The screen has fixed layout calculations that need more space
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await pumpWithMaterialApp(
    tester,
    QuestionScreenV2(
      gameId: gameId,
      realtime: realtime,
      questionCount: questionCount,
      isHost: isHost,
      session: session,
      initialPlayers: initialPlayers,
      showLeaveButton: showLeaveButton,
    ),
  );
}

/// A stream controller wrapper that replays the last value to new subscribers
/// This mimics Firebase stream behavior where subscribing gets the current state
class _ReplayStreamController<T> {
  final StreamController<T> _controller = StreamController<T>.broadcast();
  T? _lastValue;
  bool _hasValue = false;

  /// Get a stream that will replay the last value (if any) to new subscribers
  Stream<T> get stream {
    if (_hasValue && _lastValue != null) {
      // Create a stream controller that emits the cached value then forwards from broadcast
      final replayController = StreamController<T>();

      // Emit the cached value immediately
      replayController.add(_lastValue as T);

      // Forward all future events from the broadcast stream
      final subscription = _controller.stream.listen(
        (event) => replayController.add(event),
        onError: (error, stackTrace) => replayController.addError(error, stackTrace),
        onDone: () => replayController.close(),
      );

      // Clean up subscription when replay stream is cancelled
      replayController.onCancel = () {
        subscription.cancel();
      };

      return replayController.stream;
    }
    return _controller.stream;
  }

  /// Add a value to the stream and store it for replay
  void add(T value) {
    _lastValue = value;
    _hasValue = true;
    _controller.add(value);
  }

  /// Close the underlying controller
  void close() {
    _controller.close();
  }
}

/// Creates a mock GameRealtime with a stream controller for testing
class MockGameRealtimeWithStream {
  final MockGameRealtime mock;
  final StreamController<GameSnapshot> streamController;

  // Question-specific stream controllers with replay capability
  // Map from questionIndex to controllers
  final Map<int, _ReplayStreamController<RevealedQuestion>> _questionStreamControllers = {};
  final Map<int, _ReplayStreamController<RevealPayload>> _revealStreamControllers = {};
  final Map<int, _ReplayStreamController<PlayersAnswersSnapshot>> _playersAnswersStreamControllers = {};

  MockGameRealtimeWithStream()
      : mock = MockGameRealtime(),
        streamController = StreamController<GameSnapshot>.broadcast();

  /// Get or create a stream controller for revealed questions at a given index
  _ReplayStreamController<RevealedQuestion> _getQuestionStreamController(int questionIndex) {
    return _questionStreamControllers.putIfAbsent(
      questionIndex,
      () => _ReplayStreamController<RevealedQuestion>(),
    );
  }

  /// Get or create a stream controller for reveal payloads at a given index
  _ReplayStreamController<RevealPayload> _getRevealStreamController(int questionIndex) {
    return _revealStreamControllers.putIfAbsent(
      questionIndex,
      () => _ReplayStreamController<RevealPayload>(),
    );
  }

  /// Get or create a stream controller for players answers at a given index
  _ReplayStreamController<PlayersAnswersSnapshot> _getPlayersAnswersStreamController(int questionIndex) {
    return _playersAnswersStreamControllers.putIfAbsent(
      questionIndex,
      () => _ReplayStreamController<PlayersAnswersSnapshot>(),
    );
  }

  void dispose() {
    streamController.close();
    for (final controller in _questionStreamControllers.values) {
      controller.close();
    }
    for (final controller in _revealStreamControllers.values) {
      controller.close();
    }
    for (final controller in _playersAnswersStreamControllers.values) {
      controller.close();
    }
  }
}

/// Helper to create and configure a mock GameRealtime with a stream
MockGameRealtimeWithStream createMockRealtimeWithStream({
  required String currentPlayerId,
  required String gameId,
  GameSnapshot? initialSnapshot,
}) {
  final helper = MockGameRealtimeWithStream();

  // Configure mock properties
  when(() => helper.mock.currentPlayerId).thenReturn(currentPlayerId);

  // Configure watchGame to return the stream
  when(() => helper.mock.watchGame(gameId))
      .thenAnswer((_) => helper.streamController.stream);

  // Configure command methods (no-op by default)
  when(() => helper.mock.submitAnswer(any(), any(), any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.goNext(any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.upvoteQuestion(any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.deUpvoteQuestion(any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.downvoteQuestion(any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.deDownvoteQuestion(any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.setUserLocale(any()))
      .thenAnswer((_) async => {});

  when(() => helper.mock.requestForceReveal(any(), any()))
      .thenAnswer((_) async => {});

  // Set up stream mocks for questions to return the stored stream controllers
  // The streams are created on-demand and stored in the helper for the test lifecycle
  when(() => helper.mock.revealedQuestion(any(), any())).thenAnswer((invocation) {
    final questionIndex = invocation.positionalArguments[1] as int;
    return helper._getQuestionStreamController(questionIndex).stream;
  });

  when(() => helper.mock.revealsForQuestion(any(), any())).thenAnswer((invocation) {
    final questionIndex = invocation.positionalArguments[1] as int;
    return helper._getRevealStreamController(questionIndex).stream;
  });

  when(() => helper.mock.playersAnswersForQuestion(any(), any())).thenAnswer((invocation) {
    final questionIndex = invocation.positionalArguments[1] as int;
    return helper._getPlayersAnswersStreamController(questionIndex).stream;
  });

  // Emit initial snapshot if provided
  if (initialSnapshot != null) {
    helper.streamController.add(initialSnapshot);
  }

  return helper;
}

/// Helper to create a basic game snapshot for a question
GameSnapshot createSnapshotWithQuestion({
  required String questionUid,
  required String currentPlayerId,
  int questionNumber = 1,
  int nQuestions = 5,
  bool isHost = true,
  Map<String, PlayerSummary>? players,
}) {
  return GameSnapshotFixtures.questionN(
    questionNumber: questionNumber,
    nQuestions: nQuestions,
    questionUid: questionUid,
    currentPlayerId: currentPlayerId,
    isHost: isHost,
    players: players,
  );
}

/// Helper to emit events to question streams for a specific question
///
/// This function adds events to the replay stream controllers managed by
/// MockGameRealtimeWithStream. The replay controllers store the last value
/// and emit it to new subscribers, mimicking Firebase stream behavior.
/// This means events can be set up before or after the controller subscribes.
void setupQuestionStreams(
  MockGameRealtimeWithStream helper,
  String gameId,
  int questionIndex, {
  RevealedQuestion? revealedQuestion,
  RevealPayload? revealPayload,
  PlayersAnswersSnapshot? playersAnswers,
}) {
  // Add revealed question to replay stream
  if (revealedQuestion != null) {
    helper._getQuestionStreamController(questionIndex).add(revealedQuestion);
  }

  // Add reveal payload to replay stream
  if (revealPayload != null) {
    helper._getRevealStreamController(questionIndex).add(revealPayload);
  }

  // Add players answers to replay stream
  if (playersAnswers != null) {
    helper._getPlayersAnswersStreamController(questionIndex).add(playersAnswers);
  }
}
