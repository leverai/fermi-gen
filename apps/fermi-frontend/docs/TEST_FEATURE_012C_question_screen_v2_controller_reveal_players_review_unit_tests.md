## TEST_FEATURE_012C – `QuestionScreenV2Controller` reveal, players & review unit tests

### Scope

Implement the **reveal, players, review, and meta-behavior** `QuestionScreenV2Controller` unit tests from `docs/TESTS.md`:

- **Unit Tests → Controllers → `QuestionScreenV2Controller`**
  - Group 8: Reveal Handling
  - Group 9: Players Answers Handling
  - Group 10: Review Mode
  - Group 11: Voting
  - Group 12: Locale Management
  - Group 13: Confetti Management
  - Group 14: Player Controllers

This feature focuses on behavior after answers are revealed, how players and scores are managed, how review mode works, and how voting/locale/confetti and per-player controllers are coordinated.

### Code / Files Involved

- `lib/screens/question_v2/question_screen_v2_controller.dart`
- Supporting models:
  - `lib/screens/question_v2/models/question_state.dart`
  - `lib/screens/question_v2/models/answer_result.dart`
  - `lib/models/answer_value.dart`
- Services and state:
  - `lib/services/game_realtime.dart`
  - `lib/state/question_pane_controller.dart`
  - `lib/state/review_vote_overrides.dart`
  - Player controller bindings used for the question screen.

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Controllers → `QuestionScreenV2Controller`”**, groups 8–14.
- `docs/TESTING_GUIDELINES.md`
  - Grouping and edge-case coverage.
- `docs/TEST_FIXTURES.md`
  - `game_snapshots.dart`, `question_data.dart`, `player_data.dart` (for reveal, scores, and review mode).

### Fixtures & Helpers

- Use fixtures to simulate:
  - Game snapshots before and after reveal.
  - Multi-player score distributions and highest-scorer scenarios.
  - Finished games with multiple questions for review mode navigation.
- Use mocks:
  - `MockGameRealtime` to emit reveal events, score updates, and vote/locale commands.

### Tasks for this Feature

1. Create tests in `test/unit/controllers/question_screen_v2_controller_012C/` folder (following the same organization pattern as 012A and 012B).
2. Implement the following groups from `docs/TESTS.md`:
   - **Reveal Handling**
   - **Players Answers Handling**
   - **Review Mode**
   - **Voting**
   - **Locale Management**
   - **Confetti Management**
   - **Player Controllers**
3. Ensure:
   - That reveal behavior matches how the UI expects correct answers, scores, and colors to be surfaced.
   - That review mode logic properly disables live behaviors (submissions/timers) and replays cached states.
   - That voting and locale changes are propagated via realtime/mocks as expected.
   - For the `should call reveal on AnswerController` test, verify that the `reveal` method is called on a mock `AnswerController`. The visual animation is tested in `TEST_FEATURE_032`.
   - For the `should call triggerConfetti on the correct PlayerWidgetController` test, verify that `triggerConfetti` is called on the correct mock `PlayerWidgetController`. The visual confetti effect is tested in `TEST_FEATURE_032`.

### Done Checklist

- [x] Tests are organized in `test/unit/controllers/question_screen_v2_controller_012C/` folder with separate files for each test group.
- [x] No real network/Firebase usage; all realtime behavior is simulated via mocks and fixtures.
- [x] `fvm flutter test test/unit/controllers/question_screen_v2_controller_012C/` passes.
- [x] Any new fixtures/helpers for reveal, players, or review mode are documented in `docs/TEST_FIXTURES.md`.

### Out of Scope

- Do not add new tests for initialization, indexing, disposal, answers, or timers; those belong to 012A and 012B.
- Do not refactor or modify unrelated production code beyond what is necessary to expose hooks for testing these behaviors.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies from the outside.

### Continuity Notes

- **Implementation completed**: All test groups (Reveal Handling, Players Answers Handling, Review Mode, Voting, Locale Management, Confetti Management, Player Controllers) have been implemented with 34 passing tests.

- **Test Organization**: Tests have been split into separate files within the `question_screen_v2_controller_012C/` folder for better maintainability. Each test group has its own file, and shared utilities are in `test_helpers.dart`.

- **Timing Considerations**: The controller sets up stream bindings asynchronously when `GameSnapshot` is emitted. Tests must wait for bindings to be established (typically 100ms) before emitting `RevealedQuestion` or other stream events. This ensures that `questionUid` is properly set and state is initialized before assertions.

- **Confetti Rank Calculation**: The confetti rank is calculated from the last question state (index `questionCount - 1`) when entering review mode. Tests must ensure the last question state has players before entering review mode, otherwise `confettiRank` will be null.

- **Unit Conversion**: The `getRevealedAnswer` method converts unit IDs to abbreviations using `unitIdToAbbreviation` from the question state. This mapping is only available after `RevealedQuestion` is processed, so tests must ensure the question is received before checking the display format.

- **Voting Tests**: Voting methods require `questionUid` to be set in the question state, which only happens when `_handleQuestion` is called with a `RevealedQuestion`. Tests must wait for the question to be processed before attempting to vote.

- **Stream Initialization**: All question streams must be properly initialized before controller attachment. The test helpers set up default empty streams for all question indices to avoid null errors during binding.

- **Test Coverage**:
  - Reveal Handling: 5 tests (all passing)
  - Players Answers Handling: 6 tests (all passing)
  - Review Mode: 4 tests (all passing)
  - Voting: 6 tests (all passing)
  - Locale Management: 3 tests (all passing)
  - Confetti Management: 4 tests (all passing)
  - Player Controllers: 6 tests (all passing)
