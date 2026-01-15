# Survival Leaderboard Frontend Contract

This document describes the API for the survival mode streak leaderboard.

## Overview

The leaderboard shows all players sorted by their longest survival streak. Players with active (in-progress) runs are shown before players with completed runs at the same streak.

## Endpoint

### `GET /survival/leaderboard`

Get the global survival streak leaderboard with pagination.

#### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | int | 1 | Page number (1-indexed) |
| `page_size` | int | 25 | Items per page (1-100) |

#### Response Schema

```typescript
interface LeaderboardEntry {
  rank: number;              // Dense rank (ties share same rank)
  display_name: string | null;
  picture: string | null;    // Avatar URL
  best_streak: number;       // Longest streak achieved
  is_completed: boolean;     // Whether best run has ended
}

interface LeaderboardResponse {
  entries: LeaderboardEntry[];      // Paginated list
  current_user: LeaderboardEntry | null; // Current user's entry (if any)
  total_count: number;              // Total users on leaderboard
  page: number;
  page_size: number;
  total_pages: number;
}
```

#### Example Response

```json
{
  "entries": [
    {
      "rank": 1,
      "display_name": "TopPlayer",
      "picture": "https://example.com/avatar1.jpg",
      "best_streak": 42,
      "is_completed": false
    },
    {
      "rank": 2,
      "display_name": "SecondPlace",
      "picture": null,
      "best_streak": 38,
      "is_completed": true
    }
  ],
  "current_user": {
    "rank": 15,
    "display_name": "CurrentPlayer",
    "picture": "https://example.com/avatar3.jpg",
    "best_streak": 12,
    "is_completed": true
  },
  "total_count": 150,
  "page": 1,
  "page_size": 25,
  "total_pages": 6
}
```

## Ranking Rules

1. **Sorting**: Players are sorted by `best_streak` in descending order
2. **Active vs Completed**: At the same streak, active runs (ongoing streaks) appear before completed runs
3. **Dense Ranking**: Ties share the same rank (e.g., if 3 players have streak 10, they all get rank 5, not 5/6/7)

## Frontend Implementation

### Display Layout

```
┌─────────────────────────────────────┐
│ 🏆 Survival Leaderboard             │
├─────────────────────────────────────┤
│ #1  👤 TopPlayer         42 🔥      │
│ #2  👤 SecondPlace       38         │
│ #2  👤 TiedPlayer        38         │
│ #4  👤 FourthPlace       35         │
│ ...                                 │
├─────────────────────────────────────┤
│ Your Rank: #15 (12 streak)          │
└─────────────────────────────────────┘
```

### Key UI Elements

1. **Leaderboard List**: Paginated, scrollable list of entries
2. **Current User Section**: Always visible, shows the current user's rank even if not on current page
3. **Active Run Indicator**: Consider showing 🔥 or similar for `is_completed: false` (ongoing streak)
4. **Pagination Controls**: Next/Previous or infinite scroll

### Fetching Strategy

```dart
// Fetch first page on screen load
final response = await apiService.getSurvivalLeaderboard(page: 1);

// Pagination: fetch next page when scrolling near bottom
final nextPage = await apiService.getSurvivalLeaderboard(page: currentPage + 1);
```

### Handling Empty State

If `current_user` is `null`, the user has never played survival mode. Consider showing:
- "Play survival mode to appear on the leaderboard!"
- Quick link to start a survival run

### Refresh Behavior

- Refresh leaderboard when returning from a survival game (streak may have changed)
- Pull-to-refresh for manual updates
- Consider periodic refresh if screen is visible for extended time

## Error Handling

| Status | Meaning | Frontend Action |
|--------|---------|-----------------|
| 401 | Unauthorized | Redirect to login |
| 500 | Server error | Show retry option |
