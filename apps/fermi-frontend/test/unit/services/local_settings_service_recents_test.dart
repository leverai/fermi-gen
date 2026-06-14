import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';

/// Unit tests for the smart-search recents cache in [LocalSettingsService].
///
/// Covers the testable core of decision #2 "Recents detail":
/// - case-insensitive dedup
/// - MRU reordering
/// - 10-item cap / least-recently-used eviction
/// - raw trimmed storage (original casing preserved)
/// - per-user-id keying
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalSettingsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = LocalSettingsService.instance;
    service.resetForTest();
    await service.initialize();
  });

  group('addRecentSearch / getRecentSearches', () {
    test('stores a single trimmed query and reads it back', () async {
      await service.addRecentSearch('user1', '  space scale  ');

      final recents = await service.getRecentSearches('user1');
      expect(recents, ['space scale']);
    });

    test('ignores empty / whitespace-only queries', () async {
      await service.addRecentSearch('user1', '   ');
      await service.addRecentSearch('user1', '');

      expect(await service.getRecentSearches('user1'), isEmpty);
    });

    test('preserves original casing of the stored string', () async {
      await service.addRecentSearch('user1', 'Christmas Trees');

      expect(await service.getRecentSearches('user1'), ['Christmas Trees']);
    });

    test('most-recent-first ordering (MRU)', () async {
      await service.addRecentSearch('user1', 'first');
      await service.addRecentSearch('user1', 'second');
      await service.addRecentSearch('user1', 'third');

      expect(await service.getRecentSearches('user1'),
          ['third', 'second', 'first']);
    });

    test(
        're-adding an existing query (case-insensitive) moves it to front '
        'without duplicating', () async {
      await service.addRecentSearch('user1', 'space');
      await service.addRecentSearch('user1', 'time');
      await service.addRecentSearch('user1', 'planets');

      // Re-add "space" with different casing.
      await service.addRecentSearch('user1', 'SPACE');

      final recents = await service.getRecentSearches('user1');
      // Only one "space" entry, now at the front; original casing of the
      // newly-added value is preserved.
      expect(recents, ['SPACE', 'planets', 'time']);
      expect(recents.where((e) => e.toLowerCase() == 'space').length, 1);
    });

    test('caps at 10 entries and evicts the least-recently-used', () async {
      // Add 11 distinct queries q1..q11.
      for (var i = 1; i <= 11; i++) {
        await service.addRecentSearch('user1', 'q$i');
      }

      final recents = await service.getRecentSearches('user1');
      expect(recents.length, 10);
      // q11 is most recent (front); q1 (oldest) was evicted.
      expect(recents.first, 'q11');
      expect(recents.contains('q1'), isFalse);
      expect(recents.last, 'q2');
    });

    test('is keyed per user id', () async {
      await service.addRecentSearch('userA', 'alpha');
      await service.addRecentSearch('userB', 'beta');

      expect(await service.getRecentSearches('userA'), ['alpha']);
      expect(await service.getRecentSearches('userB'), ['beta']);
    });

    test('recentSearches notifier reflects the most recently loaded user',
        () async {
      await service.addRecentSearch('userA', 'alpha');
      await service.addRecentSearch('userB', 'beta');

      await service.getRecentSearches('userA');
      expect(service.recentSearches.value, ['alpha']);

      await service.getRecentSearches('userB');
      expect(service.recentSearches.value, ['beta']);
    });
  });
}
