import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/firestore_game_realtime.dart';
import '../../../helpers/mock_factories.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  const String gameId = 'test-game-123';
  const String currentPlayerId = 'player-1';

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('Command Execution', () {
    test('should call submit function on submitAnswer', () async {
      // ARRANGE
      bool submitCalled = false;
      String? calledGameId;
      int? calledIndex;
      AnswerValue? calledAnswer;

      final testRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        submit: (gameId, index, answer) async {
          submitCalled = true;
          calledGameId = gameId;
          calledIndex = index;
          calledAnswer = answer;
        },
      );

      // ACT
      await testRealtime.submitAnswer(
        gameId,
        0,
        const AnswerValue(number: 5, orderOfMagnitude: 'K', unit: 'm'),
      );

      // ASSERT
      expect(submitCalled, true);
      expect(calledGameId, gameId);
      expect(calledIndex, 0);
      expect(calledAnswer?.number, 5);
      expect(calledAnswer?.orderOfMagnitude, 'K');
      expect(calledAnswer?.unit, 'm');
    });

    test('should call next function on goNext', () async {
      // ARRANGE
      bool nextCalled = false;
      String? calledGameId;

      final testRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        next: (gameId) async {
          nextCalled = true;
          calledGameId = gameId;
        },
      );

      // ACT
      await testRealtime.goNext(gameId);

      // ASSERT
      expect(nextCalled, true);
      expect(calledGameId, gameId);
    });

    test('should call vote functions correctly', () async {
      // ARRANGE
      final voteCalls = <String, String>{};

      final testRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        upvote: (uid) async {
          voteCalls['upvote'] = uid;
        },
        deUpvote: (uid) async {
          voteCalls['deUpvote'] = uid;
        },
        downvote: (uid) async {
          voteCalls['downvote'] = uid;
        },
        deDownvote: (uid) async {
          voteCalls['deDownvote'] = uid;
        },
      );

      // ACT
      await testRealtime.upvoteQuestion('q1');
      await testRealtime.deUpvoteQuestion('q1');
      await testRealtime.downvoteQuestion('q2');
      await testRealtime.deDownvoteQuestion('q2');

      // ASSERT
      expect(voteCalls['upvote'], 'q1');
      expect(voteCalls['deUpvote'], 'q1');
      expect(voteCalls['downvote'], 'q2');
      expect(voteCalls['deDownvote'], 'q2');
    });

    test('should call locale functions correctly', () async {
      // ARRANGE
      String? setLocaleValue;

      final testRealtime = FirestoreGameRealtime(
        currentPlayerId: currentPlayerId,
        firestore: fakeFirestore,
        resolveLocale: () => 'US',
        setLocale: (locale) async {
          setLocaleValue = locale;
        },
      );

      // ACT
      final locale = testRealtime.currentLocale;
      await testRealtime.setUserLocale('EU');

      // ASSERT
      expect(locale, 'US');
      expect(setLocaleValue, 'EU');
    });
  });
}
