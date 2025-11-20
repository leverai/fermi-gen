import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/player_widget_controller.dart';

void main() {
  group('PlayerWidgetController - Binding', () {
    late PlayerWidgetController controller;

    setUp(() {
      controller = PlayerWidgetController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('should bind callbacks', () {
      // ARRANGE
      bool setRoundScoreCalled = false;
      bool setScoreCalled = false;
      bool triggerConfettiCalled = false;
      bool clearConfettiCalled = false;
      int? capturedRoundScore;
      int? capturedScore;

      // ACT
      controller.bind(
        setRoundScore: (newRoundScore) {
          setRoundScoreCalled = true;
          capturedRoundScore = newRoundScore;
        },
        setScore: (newScore) {
          setScoreCalled = true;
          capturedScore = newScore;
        },
        triggerConfetti: () {
          triggerConfettiCalled = true;
        },
        clearConfetti: () {
          clearConfettiCalled = true;
        },
      );

      // ASSERT
      expect(setRoundScoreCalled, false);
      expect(setScoreCalled, false);
      expect(triggerConfettiCalled, false);
      expect(clearConfettiCalled, false);

      // Verify callbacks are stored by calling controller methods
      controller.setRoundScore(10);
      expect(setRoundScoreCalled, true);
      expect(capturedRoundScore, 10);

      controller.setScore(20);
      expect(setScoreCalled, true);
      expect(capturedScore, 20);

      controller.triggerConfetti();
      expect(triggerConfettiCalled, true);

      controller.clearConfetti();
      expect(clearConfettiCalled, true);
    });

    test('should replay last round score on bind', () {
      // ARRANGE
      int? capturedRoundScore;
      controller.setRoundScore(15); // Set score before binding

      // ACT
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

    test('should replay last score on bind', () {
      // ARRANGE
      int? capturedScore;
      controller.setScore(25); // Set score before binding

      // ACT
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

    test('should replay both last round score and last score on bind', () {
      // ARRANGE
      int? capturedRoundScore;
      int? capturedScore;
      controller.setRoundScore(10);
      controller.setScore(30);

      // ACT
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
      expect(capturedRoundScore, 10);
      expect(capturedScore, 30);
    });

    test('should not replay scores when null on bind', () {
      // ARRANGE
      bool setRoundScoreCalled = false;
      bool setScoreCalled = false;

      // ACT
      controller.bind(
        setRoundScore: (_) {
          setRoundScoreCalled = true;
        },
        setScore: (_) {
          setScoreCalled = true;
        },
        triggerConfetti: () {},
        clearConfetti: () {},
      );

      // ASSERT
      expect(setRoundScoreCalled, false);
      expect(setScoreCalled, false);
    });
  });
}
