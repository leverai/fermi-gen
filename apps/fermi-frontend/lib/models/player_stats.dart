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

class PlayerStats {
  final int totalPartyGames;
  final int totalDailyGuesses;
  final int averagePercentile;
  final int level;

  const PlayerStats({
    required this.totalPartyGames,
    required this.totalDailyGuesses,
    required this.averagePercentile,
    required this.level,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      totalPartyGames: json['total_party_games'] as int? ?? 0,
      totalDailyGuesses: json['total_daily_guesses'] as int? ?? 0,
      averagePercentile: json['average_percentile'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
    );
  }
}
