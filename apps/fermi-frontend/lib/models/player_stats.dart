class PlayerStatsResponse {
  final String playerId;
  final PlayerQuantiles playerQuantiles;

  const PlayerStatsResponse(
      {required this.playerId, required this.playerQuantiles});

  factory PlayerStatsResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> stats =
        (json['stats'] as Map<String, dynamic>? ?? const {});
    return PlayerStatsResponse(
      playerId: json['player_id']?.toString() ?? '',
      playerQuantiles: PlayerQuantiles.fromJson(
          stats['player_quantiles'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class PlayerQuantiles {
  final List<CategoryDifficultyQuantile> byCategoryAndDifficulty;
  final List<CategoryQuantile> byCategory;
  final List<DifficultyQuantile> byDifficulty;
  final num? overall;

  const PlayerQuantiles({
    required this.byCategoryAndDifficulty,
    required this.byCategory,
    required this.byDifficulty,
    required this.overall,
  });

  factory PlayerQuantiles.fromJson(Map<String, dynamic> json) {
    final List<dynamic> byCd =
        json['by_category_and_difficulty'] as List<dynamic>? ?? const [];
    final List<dynamic> byC = json['by_category'] as List<dynamic>? ?? const [];
    final List<dynamic> byD =
        json['by_difficulty'] as List<dynamic>? ?? const [];
    return PlayerQuantiles(
      byCategoryAndDifficulty: byCd
          .whereType<Map<String, dynamic>>()
          .map(CategoryDifficultyQuantile.fromJson)
          .toList(growable: false),
      byCategory: byC
          .whereType<Map<String, dynamic>>()
          .map(CategoryQuantile.fromJson)
          .toList(growable: false),
      byDifficulty: byD
          .whereType<Map<String, dynamic>>()
          .map(DifficultyQuantile.fromJson)
          .toList(growable: false),
      overall: json['overall'] as num?,
    );
  }
}

class CategoryDifficultyQuantile {
  final String category;
  final String difficulty;
  final num? avgQuantile;
  final num? avgPercentile;

  const CategoryDifficultyQuantile({
    required this.category,
    required this.difficulty,
    this.avgQuantile,
    this.avgPercentile,
  });

  factory CategoryDifficultyQuantile.fromJson(Map<String, dynamic> json) {
    return CategoryDifficultyQuantile(
      category: json['category']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? '',
      avgQuantile: json['avg_quantile'] as num?,
      avgPercentile: json['avg_percentile'] as num?,
    );
  }
}

class CategoryQuantile {
  final String category;
  final num? avgQuantile;
  final num? avgPercentile;

  const CategoryQuantile({
    required this.category,
    this.avgQuantile,
    this.avgPercentile,
  });

  factory CategoryQuantile.fromJson(Map<String, dynamic> json) {
    return CategoryQuantile(
      category: json['category']?.toString() ?? '',
      avgQuantile: json['avg_quantile'] as num?,
      avgPercentile: json['avg_percentile'] as num?,
    );
  }
}

class DifficultyQuantile {
  final String difficulty;
  final num? avgQuantile;
  final num? avgPercentile;

  const DifficultyQuantile({
    required this.difficulty,
    this.avgQuantile,
    this.avgPercentile,
  });

  factory DifficultyQuantile.fromJson(Map<String, dynamic> json) {
    return DifficultyQuantile(
      difficulty: json['difficulty']?.toString() ?? '',
      avgQuantile: json['avg_quantile'] as num?,
      avgPercentile: json['avg_percentile'] as num?,
    );
  }
}
