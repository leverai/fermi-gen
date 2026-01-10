/// Defines the static rank data and thresholds matching the backend.
class RankDefinition {
  final int id;
  final String name;
  final int minPercentile;
  final String accuracyVibe;
  final String tagline;

  const RankDefinition({
    required this.id,
    required this.name,
    required this.minPercentile,
    required this.accuracyVibe,
    required this.tagline,
  });
}

/// Ordered from lowest to highest for display consistency in lists if needed,
/// but backend looks up highest first. We can store them in display order (1->5).
const List<RankDefinition> allRanks = [
  RankDefinition(
    id: 1,
    name: 'The Columbus',
    minPercentile: 0,
    accuracyVibe: 'Lost',
    tagline: 'India is right around the corner, I swear.',
  ),
  RankDefinition(
    id: 2,
    name: 'The Kelvin',
    minPercentile: 40,
    accuracyVibe: 'Flawed Genius',
    tagline: 'Technically correct, practically wrong.',
  ),
  RankDefinition(
    id: 3,
    name: 'The Archimedes',
    minPercentile: 75,
    accuracyVibe: 'Theoretical',
    tagline: 'Right ballpark, wrong seat.',
  ),
  RankDefinition(
    id: 4,
    name: 'The Eratosthenes',
    minPercentile: 90,
    accuracyVibe: 'Precise',
    tagline: "Give me a stick, and I'll measure the world.",
  ),
  RankDefinition(
    id: 5,
    name: 'The Fermi',
    minPercentile: 98,
    accuracyVibe: 'Uncanny',
    tagline: 'Close enough for physics.',
  ),
];
