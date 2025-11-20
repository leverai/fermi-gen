## TEST_FEATURE_044 – `PlayersRow` widget tests

### Scope

Implement `PlayersRow` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `PlayersRow`**

Cover rendering, ordering, updates, and removal of players.

### Code / Files Involved

- `lib/widgets/players_row.dart`
- `lib/widgets/player_widget.dart`
- `lib/widgets/player_widget_controller.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `PlayersRow`”**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests and layout-related assertions.
- `docs/TEST_FIXTURES.md`
  - `player_data.dart` for player lists and ranks.

### Fixtures & Helpers

- Use player fixtures to simulate:
  - Multiple players with different ranks/scores.
  - Players joining and leaving.

### Tasks for this Feature

1. Create `test/widget/widgets/players_row_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Rendering
   - Player Updates
3. Ensure:
   - Players are sorted by rank and visually aligned as expected.
   - Changes in rank and presence are reflected in the rendered row.

### Done Checklist

- [x] `players_row_test.dart` created with all required groups.
- [x] Tests confirm correct ordering and updates when players change.
- [x] `fvm flutter test test/widget/widgets/players_row_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

**Completed**: All PlayersRow widget tests implemented and passing (13 tests total).

**Test Groups Implemented**:
1. **Rendering** (8 tests): Verified display of all players, sorting by rank, alignment, empty list handling, scrollable layout for >3 players, tiebreaker sorting, rank icons, and current player highlighting.
2. **Player Updates** (5 tests): Verified updates when players change, reordering when ranks change, player removal, score updates, and transition between layout modes.

**Key Implementation Details**:
- **Sorting behavior**: `PlayersRow` only sorts players internally when `showRankIcons: true` is set. Otherwise, it expects pre-sorted players from the parent. This is by design - sorting is conditional based on whether rank icons are being displayed (typically in review mode).
- **Layout modes**: PlayersRow uses two different layouts:
  - ≤3 players: Centered `Row` with `AnimatedSlide` for reordering animations
  - >3 players: `SingleChildScrollView` with `AnimatedPositioned` for horizontal scrolling
- **Tiebreaker**: When players have equal scores, they are sorted alphabetically by `playerId` for stable ordering.
- **Player ordering assertions**: Used `tester.widgetList<PlayerWidget>()` to get widgets in render order and verified `playerId` and `score` properties.

**Fixtures Used**:
- Created inline `PlayerState` objects with various scores and player IDs to test different scenarios.
- No specific fixtures from `player_data.dart` were needed as the tests use simple player states.

**No upstream issues found** - all tests passed after fixing initial misunderstanding about sorting behavior.
