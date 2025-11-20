import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';

void main() {
  group('PlayerWidgetController - State Persistence', () {
    late PlayerWidgetController controller;

    setUp(() {
      controller = PlayerWidgetController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('should remember last round score', () {
      // ARRANGE
      controller.setRoundScore(15);

      // ACT
      int? capturedRoundScore;
      controller.bind(
        setRoundScore: (newRoundScore) {
          capturedRoundScore = newRoundScore;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ASSERT
      expect(capturedRoundScore, 15);
    });

    test('should remember last score', () {
      // ARRANGE
      controller.setScore(25);

      // ACT
      int? capturedScore;
      controller.bind(
        setRoundScore: (_) {},
        setScore: (newScore) {
          capturedScore = newScore;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ASSERT
      expect(capturedScore, 25);
    });

    test('should remember multiple score updates', () {
      // ARRANGE
      controller.setRoundScore(10);
      controller.setRoundScore(20);
      controller.setScore(50);
      controller.setScore(100);

      // ACT
      int? capturedRoundScore;
      int? capturedScore;
      controller.bind(
        setRoundScore: (newRoundScore) {
          capturedRoundScore = newRoundScore;
        },
        setScore: (newScore) {
          capturedScore = newScore;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ASSERT
      expect(capturedRoundScore, 20); // Last round score
      expect(capturedScore, 100); // Last cumulative score
    });

    test('should clear state on dispose', () {
      // ARRANGE
      bool callbackCalled = false;
      controller.setRoundScore(10);
      controller.setScore(20);
      controller.bind(
        setRoundScore: (_) {
          callbackCalled = true;
        },
        setScore: (_) {
          callbackCalled = true;
        },
        triggerConfetti: () {
          callbackCalled = true;
        },
        clearConfetti: () {
          callbackCalled = true;
        },
      );

      // ACT
      controller.dispose();

      // ASSERT
      // After dispose, callbacks should not be called
      callbackCalled = false;
      controller.setRoundScore(30);
      controller.setScore(40);
      controller.triggerConfetti();
      controller.clearConfetti();
      expect(callbackCalled, false);
    });

    test('should preserve last scores after dispose', () {
      // ARRANGE
      controller.setRoundScore(10);
      controller.setScore(20);

      // ACT
      controller.dispose();

      // ASSERT
      // Last scores should still be remembered (they're not cleared on dispose)
      int? capturedRoundScore;
      int? capturedScore;
      controller.bind(
        setRoundScore: (newRoundScore) {
          capturedRoundScore = newRoundScore;
        },
        setScore: (newScore) {
          capturedScore = newScore;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      expect(capturedRoundScore, 10);
      expect(capturedScore, 20);
    });
  });
}
