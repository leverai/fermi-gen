import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fermi_frontend/models/feature_announcement.dart';
import 'package:fermi_frontend/services/feature_announcement_service.dart';

void main() {
  late FeatureAnnouncementService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = FeatureAnnouncementService();
  });

  test('returns Smart Search when it is enabled and unseen', () async {
    final pending = await service.pendingFor(
      userId: 'user-a',
      smartSearchEnabled: true,
    );

    expect(pending, hasLength(1));
    expect(pending.single.id, 'party_smart_search_2026_09');
    expect(
      pending.single.action,
      FeatureAnnouncementAction.openPartySettings,
    );
  });

  test('does not announce Smart Search while its feature flag is off',
      () async {
    final pending = await service.pendingFor(
      userId: 'user-a',
      smartSearchEnabled: false,
    );

    expect(pending, isEmpty);
  });

  test('markSeen removes displayed announcements for only that user', () async {
    final pending = await service.pendingFor(
      userId: 'user-a',
      smartSearchEnabled: true,
    );

    await service.markSeen(
      userId: 'user-a',
      announcementIds: pending.map((announcement) => announcement.id),
    );

    expect(
      await service.pendingFor(
        userId: 'user-a',
        smartSearchEnabled: true,
      ),
      isEmpty,
    );
    expect(
      await service.pendingFor(
        userId: 'user-b',
        smartSearchEnabled: true,
      ),
      hasLength(1),
    );
  });

  test('returns every eligible unseen announcement in catalog order', () async {
    service = FeatureAnnouncementService(
      announcements: const <FeatureAnnouncement>[
        FeatureAnnouncement(
          id: 'newest',
          title: 'Newest',
          description: 'Newest feature',
        ),
        FeatureAnnouncement(
          id: 'smart-search',
          title: 'Smart Search',
          description: 'Search for a topic',
          requirement: FeatureAnnouncementRequirement.smartSearch,
        ),
        FeatureAnnouncement(
          id: 'oldest',
          title: 'Oldest',
          description: 'Oldest feature',
        ),
      ],
    );
    await service.markSeen(
      userId: 'user-a',
      announcementIds: const <String>['newest'],
    );

    final pending = await service.pendingFor(
      userId: 'user-a',
      smartSearchEnabled: true,
    );

    expect(
      pending.map((announcement) => announcement.id),
      <String>['smart-search', 'oldest'],
    );
  });
}
