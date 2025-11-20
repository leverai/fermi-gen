## TEST_FEATURE_011 – `LobbyScreenController` unit tests

### Scope

Implement `LobbyScreenController` unit tests as described in `docs/TESTS.md` under:

- **Unit Tests → Controllers → `LobbyScreenController`**

Focus on state management and navigation logic, not UI rendering.

### Code / Files Involved

- `lib/screens/lobby/lobby_screen_controller.dart`
- Realtime & models used by the controller:
  - `lib/services/game_realtime.dart`
  - `lib/services/firestore_game_realtime.dart`
  - `lib/models/game_config.dart` / `lib/models/player_stats.dart` (if referenced)

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Controllers → `LobbyScreenController`”**
- `docs/TESTING_GUIDELINES.md`
  - Grouping, AAA pattern, mocking guidance.
- `docs/TEST_FIXTURES.md`
  - `game_snapshots.dart` and `player_data.dart` fixtures.

### Fixtures & Helpers

- Use `game_snapshots.dart` to simulate:
  - Initial lobby state, players joining/leaving, ready state, private/public flags.
- Use `player_data.dart` for typical player lists.
- Use realtime mocks from `test/helpers/mock_factories.dart`.

### Tasks for this Feature

1. Create `test/unit/controllers/lobby_screen_controller_test.dart`.
2. Implement groups listed in `docs/TESTS.md`:
   - State Management
   - Navigation Logic
   - Game Actions
   - Leave Game
3. Stub realtime streams and API calls using mocks, not real Firebase.
4. Assert that state transitions and navigation signals match expectations.

### Done Checklist

- [x] `lobby_screen_controller_test.dart` created with all defined test groups.
- [x] All realtime and API dependencies are mocked.
- [x] `fvm flutter test test/unit/controllers/lobby_screen_controller_test.dart` passes.
- [x] Fixtures usage aligns with `docs/TEST_FIXTURES.md` (update if new helpers are introduced).

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Navigation Testing Approach**: Since `LobbyScreenController` is a `StatefulWidget` that uses `Navigator.push()` in a post-frame callback, the navigation tests verify the state transition logic rather than fully rendering the destination screen. Full navigation rendering would be tested in widget/integration tests. The tests verify that:
  - Navigation is triggered when state becomes `QUESTION_N` or `QUESTION_LAST`
  - The `_navigatedToQuestions` flag prevents double navigation
  - The correct question count is passed to the question screen

- **Mock Setup**: All `GameRealtime` methods that might be called during navigation (e.g., `revealsForQuestion`, `revealedQuestion`, `playersAnswersForQuestion`) are stubbed in `setUp()` to prevent errors when the navigation attempts to render `QuestionScreenV2`.

- **State Management**: Tests focus on verifying state updates from game snapshots (players, host status, lobby ready state, private/public flags, join URL) without requiring full widget rendering.

- **Game Actions**: Tests verify that start game and share invite actions are properly gated (host-only, lobby-ready checks) and handle errors gracefully. The actual button interactions would be tested in widget tests.

- **No New Fixtures**: All existing fixtures from `game_snapshots.dart` and `player_data.dart` were sufficient for these tests.
