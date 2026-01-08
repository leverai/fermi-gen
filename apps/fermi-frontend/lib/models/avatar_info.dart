/// Avatar info model with unlock level.
class AvatarInfo {
  final String url;
  final int unlockLevel;
  final bool unlocked;

  AvatarInfo({
    required this.url,
    required this.unlockLevel,
    required this.unlocked,
  });

  factory AvatarInfo.fromJson(Map<String, dynamic> json) {
    return AvatarInfo(
      url: json['url'] as String,
      unlockLevel: json['unlock_level'] as int,
      unlocked: json['unlocked'] as bool,
    );
  }
}
