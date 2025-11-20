## TEST_FEATURE_031 – `LobbyScreen` widget tests (including lobby ring colors)

**BugFixRequired: true**

### Scope

Implement `LobbyScreen` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Screens → `LobbyScreen`**

Additionally, address the known issue:

- **Ring color in lobby screen**:
  - All rings currently appear as `Other` (border).
  - Must follow `Self`, `Host`, `Other` rules.

You MUST fix this bug in the relevant widget(s) first, then add tests that assert the correct behavior.

### Code / Files Involved

- `lib/screens/lobby/lobby_screen.dart`
- `lib/screens/lobby/lobby_screen_controller.dart`
- Likely ring-related widgets:
  - `lib/widgets/player_widget.dart`
  - `lib/widgets/player_ring_progress.dart`
  - `lib/widgets/players_row.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Screens → `LobbyScreen`”**
  - **Integration Tests → Flows → `Full Game Flow` / `Real-time Synchronization`** (for expectations).
- `docs/TESTING_GUIDELINES.md`
  - Widget tests and keys usage.

### Fixtures & Helpers

- Use:
  - `test/fixtures/game_snapshots.dart` for lobby state snapshots.
  - `test/fixtures/player_data.dart` for host/self/other scenarios.
  - `test/helpers/mock_factories.dart` and `test/helpers/test_helpers.dart` for mocks/wrappers.

### Tasks for this Feature

1. Identify and fix the **lobby ring color** bug:
   - Ensure host, self, and other players are rendered with the correct ring colors in lobby.
2. Create `test/widget/screens/lobby_screen_test.dart`.
3. Implement all groups from `docs/TESTS.md`:
   - Rendering
   - Player Display
   - Actions
   - State Updates
4. Add specific tests to cover ring color rules in lobby (even if not explicitly listed), using fixtures to simulate:
   - Current player as host vs non-host.
   - Other players vs self.

### Done Checklist

- [x] Bug fix for lobby ring colors implemented and reviewed within `lib/`.
- [x] `lobby_screen_test.dart` created with all described groups plus ring color tests.
- [x] `fvm flutter test test/widget/screens/lobby_screen/` passes.
- [x] Any new fixtures/helpers for lobby scenarios documented in `docs/TEST_FIXTURES.md`.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

#### Bug Fix: Lobby Ring Colors

**Root Cause**: In `lib/screens/lobby/lobby_screen_controller.dart` (lines 67-76), the `PlayerState` objects created from `GameSnapshot` were missing the `playerId` field. This prevented `PlayersRow` from correctly identifying the current player (self) and applying the proper ring color.

**Fix Applied**: Added `playerId: p.playerId` to the `PlayerState` constructor in `lobby_screen_controller.dart` line 69.

**Ring Color Rules** (implemented in `lib/widgets/player_ring_progress.dart`):
- **Host**: Uses `appTheme.primary` (golden color) in both countdown and review modes
- **Self** (current player, non-host): Uses `appTheme.info` (blue-ish color) in countdown and review modes
- **Other** (neither host nor self): Uses `appTheme.border` (gray color) in countdown and review modes
- **Completed state**: All players use `appTheme.success` (green color)

In lobby, all players use `RingState.review` with a static full ring (progress = 0.0, which inverts to 100%).

**Note**: Two issues were discovered and fixed:
1. The initial implementation of `RingState.review` in `player_ring_progress.dart` did not check for host status, causing hosts to appear with border color instead of primary color in the lobby. This was fixed by adding the host check to the review case (matching the countdown logic).
2. When a host leaves and another player becomes the new host, the `PlayerWidget` did not detect the `isHost` property change and force a rebuild. This was fixed by adding a check in `didUpdateWidget` to call `setState()` when `isHost` or `isSelf` properties change, ensuring the ring color updates immediately.

#### Test Organization

Tests were split into 4 files in `test/widget/screens/lobby_screen/` to keep each under 300 lines:
- `lobby_screen_test_helpers.dart` (52 lines) - Shared setup and helper functions
- `rendering_test.dart` (172 lines) - Rendering group tests
- `player_display_test.dart` (330 lines) - Player Display group tests including ring color verification
- `actions_test.dart` (233 lines) - Actions group tests
- `state_updates_test.dart` (276 lines) - State Updates group tests

**Total: 26 tests, all passing**

#### Test Patterns and Considerations

1. **Avatar URLs**: Use `null` for `avatarUrl` in tests to avoid network image loading errors (widget tests don't support network requests).

2. **Infinite Animations**: The `LoadingAnimationWidget.fourRotatingDots` used in waiting state has an infinite animation. For tests involving `isWaiting: true`, use `await tester.pump()` instead of `await tester.pumpAndSettle()` to avoid timeout errors.

3. **Ring Color Testing**: The ring color logic is testable by verifying the `isSelf`, `isHost`, and `ringState` properties passed to `PlayerRingProgress` widgets. The actual color rendering is handled by the theme and can't be easily tested at the widget level without golden tests.

4. **Helper Function**: Created `pumpLobbyScreen()` helper in `lobby_screen_test_helpers.dart` to consistently pump LobbyScreen with default values, reducing boilerplate in tests.

#### Files Modified

**Production Code**:
- `lib/screens/lobby/lobby_screen_controller.dart` - Added `playerId` field to PlayerState creation (1 line change)
- `lib/widgets/player_ring_progress.dart` - Fixed `RingState.review` case to check for host status and apply primary color (lines 98-102)
- `lib/widgets/player_widget.dart` - Added `didUpdateWidget` check to force rebuild when `isHost` or `isSelf` properties change (lines 151-157)

**Test Code** (new files):
- `test/widget/screens/lobby_screen/lobby_screen_test_helpers.dart`
- `test/widget/screens/lobby_screen/rendering_test.dart`
- `test/widget/screens/lobby_screen/player_display_test.dart`
- `test/widget/screens/lobby_screen/actions_test.dart`
- `test/widget/screens/lobby_screen/state_updates_test.dart`
