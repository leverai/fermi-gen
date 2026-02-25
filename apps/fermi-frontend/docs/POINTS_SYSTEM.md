# Points System (Frontend)

Points are the consumable in-game currency for Fermi. This document describes how they are handled in the frontend to assist with future features like the in-game shop.

## Data Model

Points are stored in the `PlayerStats` model:

- **File**: `lib/models/player_stats.dart`
- **Field**: `int points`
- **Source**: Fetched via `GET /game/get_player_stats` (handled by `ApiService`).

## UI Display

Points are primary displayed in the `StatsCard` on the "Me" tab.

- **Currency Symbol**: `points.svg` icon (represented as Fermis).
- **Formatting**: Numbers are formatted with a thousands separator (comma) using `formatNumberWithCommas` from `lib/utils/answer_format.dart`.
- **Component**: `lib/widgets/stats_card.dart`

Example formatting: `1234` -> `[icon] 1,234`

## Implementation Details

### Refreshing Stats
The `MainScreenController` manages the refreshing of player stats. When a user navigates back to the "Me" tab or finishes a game, `refreshInBackground()` is typically called, which updates the `PlayerStats` and thus the points balance.

### Future: Spending Points
When implementing the in-game shop:
1. Use the `points` field in `PlayerStats` to check if the user has enough balance.
2. Call the appropriate backend endpoint (to be implemented) to deduct points.
3. Trigger a stats refresh to update the UI balance.

## Related Docs
- [Backend Points System](../../fermi-api/docs/POINTS_SYSTEM.md)
