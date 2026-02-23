class UserLimits {
  final int partyHostingsRemaining;
  final int survivalRunsRemaining;
  final int precisionRushRunsRemaining;

  const UserLimits({
    required this.partyHostingsRemaining,
    required this.survivalRunsRemaining,
    required this.precisionRushRunsRemaining,
  });

  factory UserLimits.fromJson(Map<String, dynamic> json) {
    return UserLimits(
      partyHostingsRemaining: (json['party_hostings_remaining'] as num).toInt(),
      survivalRunsRemaining: (json['survival_runs_remaining'] as num).toInt(),
      precisionRushRunsRemaining:
          (json['precision_rush_runs_remaining'] as num?)?.toInt() ?? 1,
    );
  }

  /// Whether the user can host a new party game.
  /// -1 indicates unlimited (Pro user).
  bool get canHost => partyHostingsRemaining != 0;

  /// Whether the user has unlimited hostings (Pro user).
  bool get isUnlimited => partyHostingsRemaining == -1;

  /// Whether the user can start a new survival run.
  /// -1 indicates unlimited (Pro user).
  bool get canPlaySurvival => survivalRunsRemaining != 0;

  /// Whether survival runs are unlimited (Pro user).
  bool get isSurvivalUnlimited => survivalRunsRemaining == -1;

  /// Whether the user can start a new precision rush run.
  /// -1 indicates unlimited (Pro user).
  bool get canPlayPrecisionRush => precisionRushRunsRemaining != 0;

  /// Whether precision rush runs are unlimited (Pro user).
  bool get isPrecisionRushUnlimited => precisionRushRunsRemaining == -1;
}
