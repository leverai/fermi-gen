class GameConfig {
  final List<CategoryInfo> categories;
  final List<DifficultyInfo> difficulties;

  const GameConfig({
    required this.categories,
    required this.difficulties,
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
    return GameConfig(categories: cats, difficulties: diffs);
  }
}

class CategoryInfo {
  final int index;
  final String name; // backend enum string
  final String slug; // display title
  final Map<String, String> theme; // argb strings
  final String picture; // absolute URL

  const CategoryInfo({
    required this.index,
    required this.name,
    required this.slug,
    required this.theme,
    required this.picture,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> themeMap =
        (json['theme'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return CategoryInfo(
      index: (json['index'] as num? ?? 0).toInt(),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      theme: themeMap.map((k, v) => MapEntry(k.toString(), v.toString())),
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
