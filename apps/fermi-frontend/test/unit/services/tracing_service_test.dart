import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/services/tracing_service.dart';

/// Unit tests for TracingService.
///
/// Tests verify:
/// - W3C traceparent format compliance
/// - Valid hex ID generation
/// - Deterministic output with seeded Random
void main() {
  group('TracingService', () {
    group('generateTraceparent', () {
      test('should return valid W3C traceparent format', () {
        // ARRANGE
        final tracing = TracingService.withRandom(Random(42));

        // ACT
        final traceparent = tracing.generateTraceparent();

        // ASSERT
        // Format: version-traceId-parentId-flags
        final parts = traceparent.split('-');
        expect(parts.length, 4, reason: 'traceparent should have 4 parts');
        expect(parts[0], '00', reason: 'version should be 00');
        expect(parts[1].length, 32, reason: 'traceId should be 32 hex chars');
        expect(parts[2].length, 16, reason: 'parentId should be 16 hex chars');
        expect(parts[3], '01', reason: 'flags should be 01 (sampled)');
      });

      test('should generate valid hex strings for trace ID', () {
        // ARRANGE
        final tracing = TracingService.withRandom(Random(123));

        // ACT
        final traceparent = tracing.generateTraceparent();
        final traceId = traceparent.split('-')[1];

        // ASSERT
        expect(
          RegExp(r'^[0-9a-f]{32}$').hasMatch(traceId),
          isTrue,
          reason: 'traceId should be 32 lowercase hex chars',
        );
      });

      test('should generate valid hex strings for span ID', () {
        // ARRANGE
        final tracing = TracingService.withRandom(Random(456));

        // ACT
        final traceparent = tracing.generateTraceparent();
        final spanId = traceparent.split('-')[2];

        // ASSERT
        expect(
          RegExp(r'^[0-9a-f]{16}$').hasMatch(spanId),
          isTrue,
          reason: 'spanId should be 16 lowercase hex chars',
        );
      });

      test('should generate unique trace IDs on each call', () {
        // ARRANGE
        final tracing = TracingService.withRandom(Random(789));

        // ACT
        final traceparent1 = tracing.generateTraceparent();
        final traceparent2 = tracing.generateTraceparent();

        // ASSERT
        expect(traceparent1, isNot(equals(traceparent2)));
      });

      test('should produce deterministic output with seeded Random', () {
        // ARRANGE
        final tracing1 = TracingService.withRandom(Random(42));
        final tracing2 = TracingService.withRandom(Random(42));

        // ACT
        final traceparent1 = tracing1.generateTraceparent();
        final traceparent2 = tracing2.generateTraceparent();

        // ASSERT - same seed should produce same output
        expect(traceparent1, equals(traceparent2));
      });
    });

    group('singleton instance', () {
      test('should return same instance', () {
        // ACT
        final instance1 = TracingService.instance;
        final instance2 = TracingService.instance;

        // ASSERT
        expect(identical(instance1, instance2), isTrue);
      });
    });
  });
}
