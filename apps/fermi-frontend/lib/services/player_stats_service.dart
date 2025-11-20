/// Pure resolver for mapping stats payload to an integer percentile.
class PlayerStatsService {
  static int resolvePercentile(
    Map<String, dynamic>? stats, {
    required String? categoryKey,
    String? difficulty,
  }) {
    if (stats == null) return 0;

    if (categoryKey == null) {
      if (difficulty != null) {
        final List<dynamic>? byDiff = (stats['stats']?['player_quantiles']
            ?['by_difficulty']) as List<dynamic>?;
        if (byDiff != null) {
          for (final dynamic item in byDiff) {
            if (item is Map<String, dynamic>) {
              if (item['difficulty']?.toString().toLowerCase() ==
                  difficulty.toLowerCase()) {
                final dynamic val =
                    item['avg_quantile'] ?? item['avg_percentile'];
                if (val is num) return val.round().clamp(0, 100);
              }
            }
          }
        }
        return 0;
      }
      final dynamic ov =
          stats['stats']?['player_quantiles']?['overall'] as num?;
      return (ov?.round() ?? 0).clamp(0, 100);
    }

    if (difficulty != null) {
      final List<dynamic>? byCatDiff = (stats['stats']?['player_quantiles']
          ?['by_category_and_difficulty']) as List<dynamic>?;
      if (byCatDiff != null) {
        for (final dynamic item in byCatDiff) {
          if (item is Map<String, dynamic>) {
            if (item['category'] == categoryKey &&
                item['difficulty']?.toString().toLowerCase() ==
                    difficulty.toLowerCase()) {
              final dynamic val =
                  item['avg_quantile'] ?? item['avg_percentile'];
              if (val is num) return val.round().clamp(0, 100);
            }
          }
        }
      }
    }

    final List<dynamic>? byCat =
        (stats['stats']?['player_quantiles']?['by_category']) as List<dynamic>?;
    if (byCat != null) {
      for (final dynamic item in byCat) {
        if (item is Map<String, dynamic>) {
          if (item['category'] == categoryKey) {
            final dynamic val = item['avg_quantile'] ?? item['avg_percentile'];
            if (val is num) return val.round().clamp(0, 100);
          }
        }
      }
    }

    return stats['stats']?['player_quantiles']?['overall'] as int? ?? 0;
  }
}
