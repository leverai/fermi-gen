/// Defines the available predefined sound profiles for the Live Typing Text widget.
enum LttSoundProfile {
  ios('ios', 'iOS', cost: 0),
  alpaca('alpaca', 'Alpaca', cost: 2500),
  gateronBlackInk('gateron-black-ink', 'Gateron Black Ink', cost: 1500),
  gateronRedInk('gateron-red-ink', 'Gateron Red Ink', cost: 1000),
  holyPanda('holy-panda', 'Holy Panda', cost: 2000),
  mxBlack('mx-black', 'Cherry MX Black', cost: 1250),
  mxBlue('mx-blue', 'Cherry MX Blue', cost: 500),
  mxBrown('mx-brown', 'Cherry MX Brown', cost: 1000);

  /// The folder name under assets/sounds/ltt/ for this profile.
  final String pathName;

  /// The human-readable display name for the profile.
  final String displayName;

  /// Cost in points to purchase. 0 means free (owned by default).
  final int cost;

  const LttSoundProfile(this.pathName, this.displayName, {required this.cost});

  /// Whether this profile is free (owned by default).
  bool get isFree => cost == 0;
}
