enum FeatureAnnouncementRequirement {
  none,
  smartSearch,
}

enum FeatureAnnouncementAction {
  openPartySettings,
}

class FeatureAnnouncement {
  const FeatureAnnouncement({
    required this.id,
    required this.title,
    required this.description,
    this.requirement = FeatureAnnouncementRequirement.none,
    this.action,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String description;
  final FeatureAnnouncementRequirement requirement;
  final FeatureAnnouncementAction? action;
  final String? actionLabel;
}

const List<FeatureAnnouncement> activeFeatureAnnouncements =
    <FeatureAnnouncement>[
  FeatureAnnouncement(
    id: 'party_smart_search_2026_09',
    title: 'Smart Search in Party Mode',
    description:
        'Build a party round around almost any topic. Open Party Settings and '
        'try something like “space”, or “How many X can fit in Y”.',
    requirement: FeatureAnnouncementRequirement.smartSearch,
    action: FeatureAnnouncementAction.openPartySettings,
    actionLabel: 'Try Smart Search',
  ),
];
