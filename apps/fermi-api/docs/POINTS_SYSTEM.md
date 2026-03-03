# Points System

## Overview

Points are a consumable in-game currency that players earn by answering questions across all game modes. Unlike XP (which accumulates permanently for leveling), points can be spent on in-app items.

## Earning Points

**Formula:** `points_increment = score // 100`

Points are awarded in every game mode where XP is awarded:

| Game Mode | When |
|-----------|------|
| Party | On game archival (total score across all questions) |
| Daily Question | On answer submission |
| Daily Question Post-Take | On answer submission |
| Survival | On each answer |
| Precision Rush | On each answer (uses accuracy score, not TAS) |
| Ad Reward | On ad completion (fixed 500 points) |

### Ad Rewards

Players can earn a fixed **500 points** by watching a rewarded video ad. This is handled by `POST /user/earn_ad_points` which calls `UserService.earn_ad_points()`. No rate limit is applied — ad views generate revenue.

## API

Points are returned in the `PlayerStats` object via `GET /game/get_player_stats`:

```json
{
  "player_id": "...",
  "stats": {
    "xp": 500,
    "level": 6,
    "points": 320,
    ...
  }
}
```

## Database

- Column: `user.points` (BigInteger, default 0)
- Migration: `add_points_column` (revises `add_precision_rush_runs_table`)

## Key Difference from XP

| | XP | Points |
|---|---|---|
| Purpose | Leveling (non-consumable) | Currency (consumable) |
| Formula | `score // 100` | `score // 100` |
| Spending | Never spent | Spent on in-app items |
