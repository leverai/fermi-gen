import 'dart:io' show Platform;

String resolveApiBaseUrlOrThrow() {
  const raw = String.fromEnvironment('API_BASE_URL');
  if (raw.isEmpty) {
    throw StateError('Missing required dart-define: API_BASE_URL');
  }
  if (Platform.isAndroid) {
    return raw.replaceFirst('http://localhost', 'http://10.0.2.2');
  }
  return raw;
}
