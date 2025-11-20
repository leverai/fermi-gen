## TEST_FEATURE_012A – `QuestionScreenV2Controller` state & index unit tests

### Scope

Implement the **core state and index-related** `QuestionScreenV2Controller` unit tests from `docs/TESTS.md`:

- **Unit Tests → Controllers → `QuestionScreenV2Controller`**
  - Group 1: Initialization
  - Group 2: Question State Caching
  - Group 3: Index Management
  - Group 15: Disposal

This feature focuses on core controller lifecycle, internal state caching, and how the current index is managed. Other behaviors (answers, timers, players, review, voting, etc.) are covered by later features.

### Code / Files Involved

- `lib/screens/question_v2/question_screen_v2_controller.dart`
- Supporting models:
  - `lib/screens/question_v2/models/question_state.dart`
  - `lib/screens/question_v2/models/answer_result.dart`
  - `lib/models/answer_value.dart`
- Services and state:
  - `lib/services/game_realtime.dart`
  - `lib/state/question_pane_controller.dart`
  - `lib/state/review_vote_overrides.dart` (for disposal expectations, if any)

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Controllers → `QuestionScreenV2Controller`”**, groups 1, 2, 3, and 15.
- `docs/TESTING_GUIDELINES.md`
  - Emphasis on AAA pattern and grouping.
- `docs/TEST_FIXTURES.md`
  - `game_snapshots.dart`, `question_data.dart`, `player_data.dart` (for basic game/question state setup).

### Fixtures & Helpers

- Use fixture factories to simulate:
  - Different initial game states (especially live vs review).
  - Question sequences for index management.
- Use mocks:
  - `MockGameRealtime` to simulate basic game stream behavior where needed.

### Tasks for this Feature

1. Create tests in `test/unit/controllers/question_screen_v2_controller_012A/` folder.
2. Implement the following test groups from `docs/TESTS.md`:
   - **Initialization**
   - **Question State Caching**
   - **Index Management**
   - **Disposal**
3. Ensure:
   - No real network/Firebase/timer usage; use mocks and fixtures only.
   - Tests are deterministic and focus strictly on the controller’s state and index behavior.
   - For the `should call carousel controller to animate on index change` test, verify that the controller's `animateToPage` method is called on a mock `CarouselSliderController`. The visual animation itself will be tested in `TEST_FEATURE_032`.

### Done Checklist

- [x] Tests are organized in `test/unit/controllers/question_screen_v2_controller_012A/` folder with separate files:
  - `initialization_test.dart` - Initialization group (5 tests)
  - `question_state_caching_test.dart` - Question State Caching group (4 tests)
  - `index_management_test.dart` - Index Management group (5 tests)
  - `disposal_test.dart` - Disposal group (6 tests)
  - `test_helpers.dart` - Shared mocks and utilities
- [x] No real network/Firebase/timer reliance; everything is mocked or controlled.
- [x] `fvm flutter test test/unit/controllers/question_screen_v2_controller_012A/` passes (20/20 tests passing).
- [x] Any new helpers/fixtures for these groups are documented in `docs/TEST_FIXTURES.md`.

### Out of Scope

- Do not implement tests for answer input/submission, timers, reveal, players, review mode, voting, locale, or confetti; these belong to later features.
- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.

### Continuity Notes

- **Implementation completed**: All test groups (Initialization, Question State Caching, Index Management, Disposal) have been implemented with 20 passing tests.

- **Test Organization**: Tests have been split into separate files within the `question_screen_v2_controller_012A/` folder for better maintainability and easier debugging. Each test group has its own file, and shared utilities are in `test_helpers.dart`.

- **Carousel Controller Testing**: The `CarouselSliderController` is now injectable via an optional constructor parameter, allowing unit tests to inject a mock controller and verify that `animateToPage` is called with the correct parameters. The visual animation behavior should still be tested in widget tests (TEST_FEATURE_032). See `docs/BUG_REPORTS/BUG_REPORT_carousel_controller_unit_testing.md` for details on the fix.

- **Stream Setup Requirement**: When testing question state caching, all question streams must be set up before emitting a game snapshot with `questionUids`. The controller automatically binds streams for all questions in the `questionUids` list, so mocks must be configured for all indices.

- **Index Update from Backend**: The test "should call carousel controller to animate on index change" now fully verifies the carousel animation call using a mock controller. The test "should update current index from backend in live mode" verifies the index update logic, while the carousel animation verification is handled by the dedicated carousel test. The visual animation behavior will be tested in widget tests.

- **Disposal Tests**: All disposal tests verify that `dispose()` completes without errors. According to the testing guidelines, we verify that disposal completes successfully rather than checking if internal references are null, as the controller might not nullify them.

- **Test Coverage**:
  - Initialization: 5 tests (all passing)
  - Question State Caching: 4 tests (all passing)
  - Index Management: 5 tests (all passing)
  - Disposal: 6 tests (all passing)
