# Feature Request: Consolidate Stats & User Limits Refresh System

## Summary
The current refresh mechanism for player stats and user limits is fragmented across multiple code paths, leading to inconsistent behavior. When a user leaves/aborts a game early, stats don't refresh properly, but limits do. A unified, robust solution is needed.

## Problem Statement

### Current Symptoms
1. Stats card shows stale data after leaving a party game early (via leave button)
2. User limits refresh correctly in the same scenario
3. Stats refresh works when finishing a game normally

### Root Cause Analysis
The refresh logic is scattered across multiple locations with inconsistent patterns:

**Navigation Patterns:**
1. **Navigator.push flow** (from MainScreen): Returns via `.then()` callback or `shouldRefreshStats` flag
2. **go_router flow** (from invite links): Returns via `context.go('/main')` → rebuilds MainScreen → checks `shouldRefreshStats`
3. **Lobby leave flow**: Uses `Navigator.popUntil()` + `context.go('/main')`
4. **Game leave flow**: Uses `Navigator.popUntil()` + `context.go('/main')` with `shouldRefreshStats`

**Refresh Mechanisms:**
1. `MainScreenController.refreshInBackground()` - refreshes both limits AND stats
2. `MainScreenController.refreshUserLimits()` - refreshes only limits
3. `shouldRefreshStats` flag in `AuthService` - checked in `MainScreen.initState`
4. `.then()` callbacks after `Navigator.push`

**The Core Issue:**
There's no single source of truth for "user just finished gameplay, refresh everything". Different exit paths trigger different subsets of refresh logic.

## Files Involved

### Primary Concern
- [main_screen.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/main/main_screen.dart) - MainScreen initState, lobby return callback
- [main_screen_controller.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/main/main_screen_controller.dart) - Refresh methods
- [auth_service.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/services/auth_service.dart) - `shouldRefreshStats` flag

### Game Exit Paths
- [question_screen_v2.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/question_v2/question_screen_v2.dart) - Party game leave/next handlers
- [lobby_screen_controller.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/lobby/lobby_screen_controller.dart) - Lobby leave handler
- [daily_question_screen.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/daily_question/daily_question_screen.dart) - DQ submit/leave handlers

### DQ Navigation
- [daily_question_carousel.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/main/widgets/daily_question_carousel.dart) - DQ card tap handlers
- [daily_question_archive_sheet.dart](file:///home/mo/repos/leverai/fermi-gen/apps/fermi-frontend/lib/screens/main/widgets/daily_question_archive_sheet.dart) - Archive date tap handlers

## Suggested Approach

### Option A: Unified Flag System
Consolidate both stats and limits refresh into a single flag (e.g., `shouldRefreshOnReturn`) that:
- Is set by ALL game exit paths (leave, finish, abort)
- Is checked in MainScreen's `didChangeDependencies` or a lifecycle observer
- Triggers a unified refresh that handles both stats and limits

### Option B: Event-Based Refresh
Implement a simple event bus or stream that:
- Game screens emit a "gameplay completed" event when exiting
- MainScreen subscribes and triggers refresh on event receipt
- Decouples navigation from refresh logic

### Option C: Route-Based Refresh
Use go_router's lifecycle hooks to trigger refresh:
- When `/main` route becomes active after any `/lobby` or `/dq` route
- Centralize the logic in the router rather than scattered across screens

## Acceptance Criteria
1. Stats card updates after ANY game exit (finish, leave, abort) for both party and DQ
2. User limits update with the same consistency as stats
3. Single source of truth for refresh logic
4. No duplicate refresh calls (debouncing preserved)
5. Works for both Navigator.push and go_router navigation patterns

## Testing Scenarios
1. Create party → play to completion → return to stats
2. Create party → leave from lobby → return to stats
3. Create party → leave mid-game → return to stats
4. Join party via invite → complete → return to stats
5. Join party via invite → leave mid-game → return to stats
6. Play DQ → complete → return to stats
7. Play DQ → leave mid-question → return to stats
8. Navigate to DQ results → return to stats (no change expected)
