class UserLimits {
  final int partyHostingsRemaining;

  const UserLimits({required this.partyHostingsRemaining});

  factory UserLimits.fromJson(Map<String, dynamic> json) {
    return UserLimits(
      partyHostingsRemaining: (json['party_hostings_remaining'] as num).toInt(),
    );
  }

  /// Whether the user can host a new party game.
  /// -1 indicates unlimited (Pro user).
  bool get canHost => partyHostingsRemaining != 0;

  /// Whether the user has unlimited hostings (Pro user).
  bool get isUnlimited => partyHostingsRemaining == -1;
}
