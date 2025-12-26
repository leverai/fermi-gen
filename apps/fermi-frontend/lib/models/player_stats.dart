/// Response model for player stats from [GET /game/get_player_stats].
class PlayerStatsResponse {
  final String playerId;
  final PlayerStats stats;

  const PlayerStatsResponse({required this.playerId, required this.stats});

  factory PlayerStatsResponse.fromJson(Map<String, dynamic> json) {
    return PlayerStatsResponse(
      playerId: json['player_id']?.toString() ?? '',
      stats: PlayerStats.fromJson(
          json['stats'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

/// Player rank based on average percentile.
class RankInfo {
  /// Rank tier ID (1-5).
  final int id;

  /// Rank name (e.g., 'Fermi Master').
  final String name;

  /// URL to the rank image.
  final String picture;

  const RankInfo({
    required this.id,
    required this.name,
    required this.picture,
  });

  factory RankInfo.fromJson(Map<String, dynamic> json) {
    return RankInfo(
      id: json['id'] as int? ?? 1,
      name: json['name'] as String? ?? 'Observer',
      picture: json['picture'] as String? ?? '',
    );
  }
}

/// Player statistics.
class PlayerStats {
  final int totalPartyGames;
  final int totalDailyGuesses;
  final int averagePercentile;
  final RankInfo rank;
  final int level;

  const PlayerStats({
    required this.totalPartyGames,
    required this.totalDailyGuesses,
    required this.averagePercentile,
    required this.rank,
    required this.level,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      totalPartyGames: json['total_party_games'] as int? ?? 0,
      totalDailyGuesses: json['total_daily_guesses'] as int? ?? 0,
      averagePercentile: json['average_percentile'] as int? ?? 0,
      rank:
          RankInfo.fromJson(json['rank'] as Map<String, dynamic>? ?? const {}),
      level: json['level'] as int? ?? 1,
    );
  }
}
