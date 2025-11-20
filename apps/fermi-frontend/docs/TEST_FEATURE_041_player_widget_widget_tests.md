## TEST_FEATURE_041 – `PlayerWidget` widget tests (including self/host ring colors)

**BugFixRequired: true**

### Scope

Implement `PlayerWidget` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `PlayerWidget`**

Additionally, address the known issue:

- **Player ring color to herself when she's host and she submits an answer**:
  - Expected: `Host` color (primary)
  - Observed: `Self` color (info)

You MUST fix this bug in production code first, then write tests that assert the correct host/self/other ring color behavior.

### Code / Files Involved

- `lib/widgets/player_widget.dart`
- `lib/widgets/player_widget_controller.dart`
- `lib/widgets/player_ring_progress.dart`
- `lib/widgets/player_score.dart`
- `lib/widgets/player_confetti_overlay.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `PlayerWidget`”**
  - **Integration Tests → Scenarios → `Review Mode` / `Real-time Synchronization`** for expectations.
- `docs/TESTING_GUIDELINES.md`
  - Widget test guidance and keys.
- `docs/TEST_FIXTURES.md`
  - `player_data.dart` for host/self/other and scoring.

### Fixtures & Helpers

- Use:
  - `player_data.dart` to create scenarios with current player as host vs non-host.
  - `game_snapshots.dart` where helpful for timing/progress.
  - `test/helpers/test_helpers.dart` to mount the widget tree.

### Tasks for this Feature

1. Fix the **self-as-host ring color** bug:
   - Ensure `PlayerWidget` (and `player_ring_progress.dart`) correctly chooses ring colors for:
     - Self (non-host)
     - Self as host
     - Other players
2. Create `test/widget/widgets/player_widget_test.dart`.
3. Implement groups from `docs/TESTS.md`:
   - Rendering
   - Status Display
   - Ring Progress (including multi-player scenarios)
   - Score Animation
   - Confetti
   - Controller Binding
4. Add specific tests to assert the correct ring colors in all combinations of host/self/other roles.

### Done Checklist

- [x] Bug fix implemented for host/self ring color in `lib/widgets/`.
- [x] `player_widget_test.dart` created with all groups and explicit ring color tests.
- [x] `fvm flutter test test/widget/widgets/player_widget_test.dart` passes (34/34 tests passing).
- [x] Any new fixtures/helpers for player roles documented in `docs/TEST_FIXTURES.md`.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Ring Color Rules**:
  - **Countdown state**: Host uses `primary` color, self (non-host) uses `info` color, others use `border` color. Host takes precedence over self.
  - **Completed state**: Host uses `primary` color (BUG FIX: was previously always `success`), non-host uses `success` color.
  - **Review state**: Host uses `primary` color, self (non-host) uses `info` color, others use `border` color.
  - Implementation: `lib/widgets/player_ring_progress.dart` `_getRingColor()` method.
  - Tests verify all combinations in `test/widget/widgets/player_widget_test.dart` "Ring Progress" group.
