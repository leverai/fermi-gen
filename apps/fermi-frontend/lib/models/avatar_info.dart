/// Avatar info model with unlock level and group.
class AvatarInfo {
  final String url;
  final int unlockLevel;
  final bool unlocked;
  final String group;

  AvatarInfo({
    required this.url,
    required this.unlockLevel,
    required this.unlocked,
    required this.group,
  });

  factory AvatarInfo.fromJson(Map<String, dynamic> json) {
    return AvatarInfo(
      url: json['url'] as String,
      unlockLevel: json['unlock_level'] as int,
      unlocked: json['unlocked'] as bool,
      group: json['group'] as String,
    );
  }
}
