# LiveTypingText (LTT) Widget

The `LiveTypingText` widget provides an animated character-by-character text reveal similar to a typewriter or "live typing" effect. It is designed to feel human-like by varying typing speed and pausing at punctuation. It integrates tightly with an optimized audio system (`LttSoundService`) to sync keystroke sounds with visual character reveals with minimal latency.

## Key Features
- **Human-like Cadence**: The widget randomizes the delay between characters. It inserts noticeable, natural-feeling pauses after sentence-ending punctuation (`.`, `!`, `?`) and shorter pauses for internal punctuation (`,`, `;`, `:`).
- **Audio Synchronization**: Rather than looping an audio track which can easily desync from the text render, the text widget triggers a short sound `playKeystroke()` *exactly* as it adds a character to the `_displayedText` buffer.
- **Optimized Sound Architecture**: The `LttSoundService` uses a small fixed set of shared `AudioPlayer` instances (round-robin) across ALL profiles. This ensures rapid, overlapping sounds while staying safely within system resource limits.
- **Low-Latency Discovery**: The service parses the project's `AssetManifest.json` at initialization to discover assets, avoiding the overhead of creating per-file `AudioPool` objects.
- **Anti-Repetition**: If a sound profile has multiple audio assets (e.g., `press_key1.mp3`, `press_key4.mp3`), the `LttSoundService` randomly picks one for each keystroke to avoid the "machine-gun" repeating artifact.
- **Dynamic Profile Loading**: To add new sound profiles in the future, developers only need to drop mp3 files into `assets/sounds/ltt/{profile_name}/`, update the `LttSoundProfile` enum with the new profile, and pass this enum value to the widget.

## How to Use

### Basic Example
If you just want the visual typewriter effect with no sound:

```dart
LiveTypingText(
  text: "Hello world!",
  style: AppFont.primaryTextStyle(context),
  soundProfile: null,
  onTypingComplete: () {
    print("Done typing!");
  }
)
```

### With Sound Context
To use an active sound profile, pass an `LttSoundProfile` enum value to the widget. The assets must exist in the corresponding folder in `assets/sounds/ltt/`.

```dart
LiveTypingText(
  text: "Hello world!",
  style: AppFont.primaryTextStyle(context),
  soundProfile: LttSoundProfile.holyPanda,
)
```
*Note: The widget automatically asks `LttSoundService` to discover and cache the audio paths the moment the widget initializes its state, to prevent delay on the first character.*

## Sound Profile Shop

Players can browse, preview, purchase, and select sound profiles via Settings → Gameplay → "Typing sound".

### How It Works
1. **Selection**: The active profile is stored in `LocalSettingsService.selectedSoundProfile` (a `ValueNotifier`). `QuestionWidget` reads this via `ValueListenableBuilder` so changes take effect on the next question.
2. **Ownership**: Owned profiles are tracked locally in SharedPreferences via `LocalSettingsService.ownedSoundProfiles`. Free profiles (cost 0) are always owned.
3. **Purchasing**: When a player buys a profile, the backend `POST /user/spend_points` endpoint deducts points. On success, the profile is added to the local owned set.
4. **Preview**: The shop screen embeds a `LiveTypingText` widget inline for each profile, allowing players to hear the sound before buying.

### Pricing
Each `LttSoundProfile` enum value has a `cost` field (0 = free). See `lib/models/ltt_sound_profile.dart` for current prices. The iOS profile is free.

## Adding New Sound Profiles
1. Obtain 3-5 distinct short keystroke sounds (in `.mp3` format).
2. Create a new folder at `apps/fermi-frontend/assets/sounds/ltt/{new_profile_name}/`.
3. Drop the files in that directory. Their names do not matter, but using sequential names like `key1.mp3`, `key2.mp3` is good practice.
4. Update `pubspec.yaml` by adding the new profile folder path explicitly. E.g.
```yaml
assets:
  - assets/icons/
  - assets/sounds/
  - assets/sounds/ltt/
  - assets/sounds/ltt/new_profile/
  - assets/lotties/
```
  _Note: Dart's AssetManifest tool requires either the exact file or a folder path ending with a trailing slash (`/`) to include all contents of a directory. Always put the trailing slash when registering the folder._
5. Run `fvm flutter pub get` or restart your IDE/app so the changes are picked up by the AssetManifest.
6. Add the new profile to the `LttSoundProfile` enum in `lib/models/ltt_sound_profile.dart`, specifying `pathName`, `displayName`, and `cost`.
7. The `LttSoundService`, shop screen, and settings row pick it up automatically.

## Audio Resource Management

Android has a hard limit of approximately 32 concurrent `MediaPlayer` instances. To maintain stability, the app adheres to a strict "MediaPlayer Budget" across all sound services:

| Service | Max MediaPlayers | Implementation |
|---|---|---|
| `FeedbackService` | 4 | 4 `AudioPool` instances (max 1-2 players each) |
| `PACardSoundService` | 3 | 3 `AudioPool` instances (max 1 player each) |
| `ConfettiSoundService` | 4 | 1 `AudioPool` (max 3) + 1 `AudioPlayer` |
| `LttSoundService` | 3 | **3 shared `AudioPlayer` instances** (round-robin) |
| **Total** | **~14** | |

This architecture ensures that even when previewing multiple sound profiles in the shop, the app remains well within the system limit.

## Architecture Limitations & Notes
- To prevent resource exhaustion, `LttSoundService` does NOT create `AudioPool` objects for every keystroke variant. Instead, it round-robins between 3 shared players.
- While `LttSoundService` retains asset paths in memory, it releases the actual `AudioPlayer` resources only when `disposeAll()` is called.
- Sound profile purchases are tracked locally (SharedPreferences), not on the backend. This means purchases don't sync across devices. Backend involvement is limited to point deduction.
