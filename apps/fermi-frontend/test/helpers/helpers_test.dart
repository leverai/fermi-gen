import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mock_factories.dart';
import 'test_helpers.dart';

void main() {
  group('MockFactories', () {
    test('should create MockApiService', () {
      final mock = MockApiService();
      expect(mock, isA<MockApiService>());
    });

    test('should create MockAuthService', () {
      final mock = MockAuthService();
      expect(mock, isA<MockAuthService>());
    });

    test('should create MockGameRealtime', () {
      final mock = MockGameRealtime();
      expect(mock, isA<MockGameRealtime>());
    });

    test('should create MockFirestoreGameRealtime', () {
      final mock = MockFirestoreGameRealtime();
      expect(mock, isA<MockFirestoreGameRealtime>());
    });

    test('should register fallback values without error', () {
      expect(() => registerFallbackValues(), returnsNormally);
    });
  });

  group('TestHelpers', () {
    testWidgets('pumpWithMaterialApp should wrap widget in MaterialApp', (tester) async {
      const testWidget = Text('Test');
      await pumpWithMaterialApp(tester, testWidget);

      expect(find.text('Test'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('pumpWithScaffold should wrap widget in Scaffold', (tester) async {
      const testWidget = Text('Test');
      await pumpWithScaffold(tester, testWidget);

      expect(find.text('Test'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('pumpAndSettleWithMaterialApp should settle animations', (tester) async {
      const testWidget = Text('Test');
      await pumpAndSettleWithMaterialApp(tester, testWidget);

      expect(find.text('Test'), findsOneWidget);
    });
  });
}
