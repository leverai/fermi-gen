import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/main_button.dart';

void main() {
  group('MainButtonLabel Extension', () {
    test('should return correct text for all label types', () {
      // ARRANGE & ACT & ASSERT
      expect(MainButtonLabel.create.text, 'Create');
      expect(MainButtonLabel.join.text, 'Join');
      expect(MainButtonLabel.start.text, 'Start');
      expect(MainButtonLabel.submit.text, 'Submit');
      expect(MainButtonLabel.next.text, 'Next');
      expect(MainButtonLabel.finish.text, 'Finish');
    });

    test('should return "Join" for join label', () {
      // ARRANGE
      const label = MainButtonLabel.join;

      // ACT
      final text = label.text;

      // ASSERT
      expect(text, 'Join');
    });

    test('should return "Create" for create label', () {
      // ARRANGE
      const label = MainButtonLabel.create;

      // ACT
      final text = label.text;

      // ASSERT
      expect(text, 'Create');
    });
  });
}
