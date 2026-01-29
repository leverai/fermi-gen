# Percentile Achievement Cards (PAC)

The `PACard` widget is designed to be a shareable, "viral" reward mechanism. It provides feedback ranging from "God-Tier" praise to "Spectacular Failure" roasts based on the player's percentile rank.

## Usage

```dart
import 'package:fermi_frontend/widgets/pa_card.dart';

PACard(
  percentile: 99.5, // 0.0 to 100.0
  questionText: 'How many jellybeans fit in the Empire State Building?',
  userAnswer: '100 trillion',
  correctAnswer: '500 million',
)
```

### Popup Usage (Survival Mode)

When used as a popup overlay, include the `onClose` callback and `animate` flag:

```dart
PACard(
  percentile: percentile,
  questionText: question.text,
  userAnswer: formattedUserAnswer,
  correctAnswer: formattedCorrectAnswer,
  animate: true, // Bouncing entrance animation
  onClose: () => Navigator.of(ctx).pop(),
)
```

## Tiers and Logic

The card automatically selects a tier and theme color based on the `percentile` double:

| Tier | Percentile Range | Color Strategy | Mood |
| :--- | :--- | :--- | :--- |
| **GODLIKE** | >= 99 | Success (Hue + 0°) | Divine Praise |
| **EXQUISITE** | >= 95 | Hue + 53° | High Praise |
| **ACE** | >= 90 | Hue + 106° | Praise |
| **Source: Trust Me Bro** | <= 10 | Hue + 159° | Neutral / Participation |
| **WRONG GALAXY** | <= 5 | Hue + 212° | Roast |
| **Um...** | <= 1 | Hue + 265° | Savage Roast |

*Note: Colors are generated using a hue-incrementing strategy starting from the Success theme color, shifting 53° per tier. No card is shown for percentiles between 10% and 90%.*

Use `PACard.getTierForPercentile(percentile)` to check if a percentile qualifies for a card before showing the popup.

## Previewing

To preview the designs on a simulator or device, run the throw-away script:

```bash
flutter run -t lib/main_achievement_preview.dart
```
