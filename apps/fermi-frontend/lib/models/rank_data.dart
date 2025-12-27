/// Defines the static rank data and thresholds matching the backend.
class RankDefinition {
  final int id;
  final String name;
  final int minPercentile;

  const RankDefinition({
    required this.id,
    required this.name,
    required this.minPercentile,
  });
}

/// Ordered from lowest to highest for display consistency in lists if needed,
/// but backend looks up highest first. We can store them in display order (1->5).
const List<RankDefinition> allRanks = [
  RankDefinition(id: 1, name: 'Observer', minPercentile: 0),
  RankDefinition(id: 2, name: 'Guesstimator', minPercentile: 40),
  RankDefinition(id: 3, name: 'Analyst', minPercentile: 75),
  RankDefinition(id: 4, name: 'Strategist', minPercentile: 90),
  RankDefinition(id: 5, name: 'Fermi Master', minPercentile: 98),
];
