class GameConfig {
  final List<CategoryInfo> categories;
  final List<DifficultyInfo> difficulties;
  final List<RankDefinition> ranks;

  const GameConfig({
    required this.categories,
    required this.difficulties,
    required this.ranks,
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> catsJson =
        json['categories'] as List<dynamic>? ?? const [];
    final List<CategoryInfo> cats = catsJson
        .whereType<Map<String, dynamic>>()
        .map(CategoryInfo.fromJson)
        .toList(growable: false);
    final List<dynamic> diffsJson =
        json['difficulties'] as List<dynamic>? ?? const [];
    final List<DifficultyInfo> diffs = diffsJson
        .whereType<Map<String, dynamic>>()
        .map(DifficultyInfo.fromJson)
        .toList(growable: false);
    final List<dynamic> ranksJson = json['ranks'] as List<dynamic>? ?? const [];
    final List<RankDefinition> ranks = ranksJson
        .whereType<Map<String, dynamic>>()
        .map(RankDefinition.fromJson)
        .toList(growable: false);

    return GameConfig(
      categories: cats,
      difficulties: diffs,
      ranks: ranks,
    );
  }
}

class CategoryInfo {
  final int index;
  final String name; // backend enum string
  final String slug; // display title
  final String picture; // absolute URL

  const CategoryInfo({
    required this.index,
    required this.name,
    required this.slug,
    required this.picture,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      index: (json['index'] as num? ?? 0).toInt(),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
    );
  }
}

class DifficultyInfo {
  final String name; // backend enum string (e.g., "EASY")
  final String slug; // display title (e.g., "Easy")
  final String picture; // absolute URL to SVG icon

  const DifficultyInfo({
    required this.name,
    required this.slug,
    required this.picture,
  });

  factory DifficultyInfo.fromJson(Map<String, dynamic> json) {
    return DifficultyInfo(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
    );
  }
}

/// Rank tier definition from the backend.
class RankDefinition {
  final int id;
  final String name;
  final int minPercentile;
  final String accuracyVibe;
  final String tagline;
  final String picture;

  const RankDefinition({
    required this.id,
    required this.name,
    required this.minPercentile,
    required this.accuracyVibe,
    required this.tagline,
    required this.picture,
  });

  factory RankDefinition.fromJson(Map<String, dynamic> json) {
    return RankDefinition(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name']?.toString() ?? '',
      minPercentile: (json['min_percentile'] as num? ?? 0).toInt(),
      accuracyVibe: json['accuracy_vibe']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
    );
  }
}
