## TEST_FEATURE_010 – `MainScreenController` unit tests

### Scope

Implement all `MainScreenController` unit tests described in `docs/TESTS.md` under:

- **Unit Tests → Controllers → `MainScreenController`**

Focus on logic (state, selection, game creation/join) without UI.

### Code / Files Involved

- `lib/screens/main/main_screen_controller.dart`
- Any related models:
  - `lib/models/game_config.dart`
  - `lib/models/player_stats.dart`
- Services used by the controller:
  - `lib/services/api_service.dart`
  - `lib/services/auth_service.dart`
  - `lib/services/game_realtime.dart` / `lib/services/game_session.dart` (if referenced)

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Controllers → `MainScreenController`”**
- `docs/TESTING_GUIDELINES.md`
  - AAA pattern, grouping, naming rules.
- `docs/TEST_FIXTURES.md`
  - For player stats and game config fixtures.

### Fixtures & Helpers

- Use fixtures from:
  - `test/fixtures/game_snapshots.dart` (if needed for realtime interactions).
  - `test/fixtures/player_data.dart` (for stats).
- Use mocks from:
  - `test/helpers/mock_factories.dart` (e.g., `MockApiService`, `MockAuthService`, `MockGameRealtime`).

### Tasks for this Feature

1. Create `test/unit/controllers/main_screen_controller_test.dart`.
2. Mirror the test groups listed in `docs/TESTS.md`:
   - Initialization
   - Category Selection
   - Difficulty Selection
   - Privacy Toggle
   - Percentile Calculation
   - Game Creation
   - Join Random Game
   - Realtime Adapter Factory
3. For each group, implement tests with clear `"should ..."` descriptions.
4. Ensure all external dependencies (API, auth, realtime) are mocked.
5. Confirm tests are **fast** and free from network/Firebase usage.

### Done Checklist

- [x] `main_screen_controller_test.dart` created with all groups from `docs/TESTS.md`.
- [x] All dependencies are mocked; tests run fast and deterministic.
- [x] `fvm flutter test test/unit/controllers/main_screen_controller_test.dart` passes.
- [x] Any new fixtures/helpers are documented in `docs/TEST_FIXTURES.md`.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Realtime Adapter Factory Tests**: The `buildRealtimeAdapter()` method creates a `FirestoreGameRealtime` instance which requires Firebase to be initialized. These tests verify that the method exists and throws an exception when called without Firebase (as expected in unit tests). Full verification of the adapter creation and wiring is better suited for integration tests where Firebase emulators are available.

- **Error Handling**: For async methods in mocktail, we use `thenAnswer((_) async => throw error)` instead of `thenThrow(error)` to properly handle exceptions in async contexts.

- **Test Coverage**: All 38 tests pass, covering all 8 test groups:
  - Initialization (6 tests)
  - Category Selection (6 tests)
  - Difficulty Selection (3 tests)
  - Privacy Toggle (2 tests)
  - Percentile Calculation (7 tests)
  - Game Creation (6 tests)
  - Join Random Game (5 tests)
  - Realtime Adapter Factory (3 tests)

- **Mocks**: Created `MockApiService` and `MockAuthService` inline in the test file. These could be moved to `test/helpers/mock_factories.dart` if they're needed by other tests, but for now they're kept local to this test file.
