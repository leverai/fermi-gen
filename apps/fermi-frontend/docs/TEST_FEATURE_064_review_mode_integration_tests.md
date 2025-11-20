## TEST_FEATURE_064 – `Review Mode Flow` integration tests

### Scope

Implement `Review Mode Flow` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Review Mode Flow`**

Cover entering review mode, carousel navigation, player reordering, rank icons, score updates, answer display, percentile/feedback, button states, confetti, and edge cases.

### Code / Files Involved

- `lib/main.dart`
- `lib/screens/question_v2/question_screen_v2.dart`
- Widgets:
  - `lib/screens/question_v2/widgets/game_carousel.dart`
  - `lib/widgets/players_row.dart`
  - `lib/widgets/player_widget.dart`
  - `lib/widgets/rank_widget.dart`
  - `lib/widgets/player_confetti_overlay.dart`
  - `lib/widgets/rank_confetti_overlay.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Review Mode Flow`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration tests and animation handling.
- `docs/TEST_FIXTURES.md`
  - Snapshot and player data fixtures for review mode.

### Fixtures & Helpers

- Use:
  - `game_snapshots.dart` for a finished game with multiple questions and players.
  - `player_data.dart` for rank and score scenarios.

### Tasks for this Feature

1. Create `test/integration/scenarios/review_mode_test.dart`.
2. Implement all groups from `docs/TESTS.md`:
   - Navigation & Activation
   - Carousel Navigation
   - Player Reordering & Display
   - Rank Icons (Medals)
   - Score Updates & Animations
   - Answer Display
   - Percentile & Feedback Display
   - Button States & Actions
   - Confetti & Celebrations
   - Edge Cases
3. Ensure:
   - Tests simulate transition into review mode via emulator state.
   - UI remains in review mode until explicit navigation away.

### Done Checklist

- [ ] `review_mode_test.dart` created with all required groups.
- [ ] Tests cover ranking, confetti, and navigation edge cases.
- [ ] `fvm flutter test test/integration/scenarios/review_mode_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Document any helper functions you built for navigating to specific review indices and asserting player ordering._
