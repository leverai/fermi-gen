import 'package:shared_preferences/shared_preferences.dart';
import 'package:fermi_frontend/models/feature_announcement.dart';

/// Finds locally unseen feature announcements for the current user.
///
/// Announcement content ships with the app. Seen IDs are deliberately stored
/// on-device because repeating low-stakes product education after a reinstall
/// or device change is preferable to adding backend synchronization.
class FeatureAnnouncementService {
  FeatureAnnouncementService({
    this.announcements = activeFeatureAnnouncements,
  });

  static final FeatureAnnouncementService instance =
      FeatureAnnouncementService();

  static const String _seenKeyPrefix = 'seen_feature_announcements_';
  static const int _maximumPendingAnnouncements = 3;

  final List<FeatureAnnouncement> announcements;

  Future<List<FeatureAnnouncement>> pendingFor({
    required String userId,
    required bool smartSearchEnabled,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const <FeatureAnnouncement>[];

    final prefs = await SharedPreferences.getInstance();
    final seenIds = <String>{
      ...?prefs.getStringList(_seenKey(normalizedUserId)),
    };

    return announcements
        .where(
          (announcement) =>
              !seenIds.contains(announcement.id) &&
              _isEligible(
                announcement,
                smartSearchEnabled: smartSearchEnabled,
              ),
        )
        .take(_maximumPendingAnnouncements)
        .toList(growable: false);
  }

  Future<void> markSeen({
    required String userId,
    required Iterable<String> announcementIds,
  }) async {
    final normalizedUserId = userId.trim();
    final ids = announcementIds.where((id) => id.isNotEmpty).toSet();
    if (normalizedUserId.isEmpty || ids.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seenIds = <String>{
      ...?prefs.getStringList(_seenKey(normalizedUserId)),
      ...ids,
    };
    await prefs.setStringList(_seenKey(normalizedUserId), seenIds.toList());
  }

  String _seenKey(String userId) => '$_seenKeyPrefix$userId';

  bool _isEligible(
    FeatureAnnouncement announcement, {
    required bool smartSearchEnabled,
  }) {
    return switch (announcement.requirement) {
      FeatureAnnouncementRequirement.none => true,
      FeatureAnnouncementRequirement.smartSearch => smartSearchEnabled,
    };
  }
}
