import 'dart:math';

/// Generates W3C traceparent headers for cross-service tracing.
///
/// This is a lightweight implementation that generates trace context
/// without the full OpenTelemetry SDK overhead. It does NOT export traces -
/// it only provides correlation IDs that the backend uses to link spans.
///
/// W3C traceparent format: `{version}-{traceId}-{parentId}-{flags}`
/// - version: 2 hex chars (always "00" for current spec)
/// - traceId: 32 hex chars (16 bytes)
/// - parentId: 16 hex chars (8 bytes)
/// - flags: 2 hex chars (01 = sampled)
///
/// Example: `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`
///
/// See: https://www.w3.org/TR/trace-context/
class TracingService {
  static final TracingService _instance = TracingService._();
  static TracingService get instance => _instance;

  final Random _random;

  TracingService._() : _random = Random.secure();

  /// For testing: allows injection of a mock Random.
  TracingService.withRandom(this._random);

  /// Generates a new W3C traceparent header value.
  ///
  /// Each call generates a fresh trace ID and span ID, suitable for
  /// top-level requests from the mobile app.
  String generateTraceparent() {
    final traceId = _generateHexId(32); // 16 bytes = 32 hex chars
    final spanId = _generateHexId(16); // 8 bytes = 16 hex chars
    const version = '00';
    const flags = '01'; // sampled

    return '$version-$traceId-$spanId-$flags';
  }

  /// Generates a random hex string of the specified length.
  String _generateHexId(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
