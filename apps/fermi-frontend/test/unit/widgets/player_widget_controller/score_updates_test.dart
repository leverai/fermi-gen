import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';

void main() {
  group('PlayerWidgetController - Score Updates', () {
    late PlayerWidgetController controller;

    setUp(() {
      controller = PlayerWidgetController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('should set round score', () {
      // ARRANGE
      int? capturedRoundScore;
      controller.bind(
        setRoundScore: (newRoundScore) {
          capturedRoundScore = newRoundScore;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ACT
      controller.setRoundScore(42);

      // ASSERT
      expect(capturedRoundScore, 42);
    });

    test('should set cumulative score', () {
      // ARRANGE
      int? capturedScore;
      controller.bind(
        setRoundScore: (_) {},
        setScore: (newScore) {
          capturedScore = newScore;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ACT
      controller.setScore(100);

      // ASSERT
      expect(capturedScore, 100);
    });

    test('should trigger confetti', () {
      // ARRANGE
      bool confettiTriggered = false;
      controller.bind(
        setRoundScore: (_) {},
        triggerConfetti: () {
          confettiTriggered = true;
        },
        clearConfetti: () {},
      );

      // ACT
      controller.triggerConfetti();

      // ASSERT
      expect(confettiTriggered, true);
    });

    test('should clear confetti', () {
      // ARRANGE
      bool confettiCleared = false;
      controller.bind(
        setRoundScore: (_) {},
        triggerConfetti: () {},
        clearConfetti: () {
          confettiCleared = true;
        },
      );

      // ACT
      controller.clearConfetti();

      // ASSERT
      expect(confettiCleared, true);
    });

    test('should handle multiple round score updates', () {
      // ARRANGE
      final capturedScores = <int>[];
      controller.bind(
        setRoundScore: (newRoundScore) {
          capturedScores.add(newRoundScore);
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ACT
      controller.setRoundScore(10);
      controller.setRoundScore(20);
      controller.setRoundScore(30);

      // ASSERT
      expect(capturedScores, [10, 20, 30]);
    });

    test('should handle multiple cumulative score updates', () {
      // ARRANGE
      final capturedScores = <int>[];
      controller.bind(
        setRoundScore: (_) {},
        setScore: (newScore) {
          capturedScores.add(newScore);
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ACT
      controller.setScore(50);
      controller.setScore(75);
      controller.setScore(100);

      // ASSERT
      expect(capturedScores, [50, 75, 100]);
    });

    test('should handle score updates when not bound', () {
      // ACT & ASSERT - should not throw
      controller.setRoundScore(10);
      controller.setScore(20);
      controller.triggerConfetti();
      controller.clearConfetti();
    });
  });
}
