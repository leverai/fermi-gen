## TEST_FEATURE_015 – `GameRealtime` & `FirestoreGameRealtime` unit tests

### Scope

Implement tests for the realtime layer described in `docs/TESTS.md` under:

- **Unit Tests → Services → `GameRealtime` Interface**

Cover the mapping of Firestore documents to snapshots, stream behavior, and command execution.

### Code / Files Involved

- `lib/services/game_realtime.dart`
- `lib/services/firestore_game_realtime.dart`
- Possibly:
  - `lib/services/game_events.dart`
  - `lib/services/mock_game_events.dart`
  - `lib/services/demo/demo_game_realtime.dart` (for reference only)

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Services → `GameRealtime` Interface”**
- `docs/TESTING_GUIDELINES.md`
  - Unit test guidelines, mock usage.
- `docs/TEST_FIXTURES.md`
  - `game_snapshots.dart` and `question_data.dart` usage patterns.

### Fixtures & Helpers

- Use Firestore-like data from `game_snapshots.dart` and `question_data.dart`.
- If Firestore is directly used, prefer:
  - `fake_cloud_firestore` mocks, or
  - An abstraction that can be mocked.

### Tasks for this Feature

1. Create `test/unit/services/game_realtime_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - FirestoreGameRealtime Implementation
   - Stream Behavior
   - Command Execution
3. Ensure tests:
   - Validate mapping from raw Firestore docs to internal snapshot models.
   - Verify streams emit expected sequences upon simulated document changes.
   - Confirm submit/next/vote/locale commands call the correct underlying functions.

### Done Checklist

- [x] `game_realtime_test.dart` created with all test groups described.
- [x] No real network connections; Firestore is mocked/emulated in-process only.
- [x] `fvm flutter test test/unit/services/game_realtime/` passes.
- [x] `docs/TEST_FIXTURES.md` updated if additional snapshot fixtures are added.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- Tests are split into three files in `test/unit/services/game_realtime/` folder to keep each file under 300 lines:
  - `implementation_test.dart` - FirestoreGameRealtime Implementation tests
  - `streams_test.dart` - Stream Behavior tests
  - `commands_test.dart` - Command Execution tests
- Added minimal change to `FirestoreGameRealtime` constructor to allow injecting a `FirebaseFirestore` instance for testing (optional parameter, defaults to `FirebaseFirestore.instance` for backward compatibility).
- Fixed type casting issues in production code to handle `Map<dynamic, dynamic>` from `fake_cloud_firestore` by using `Map<String, dynamic>.from()` instead of direct casts.
- Created `test_helpers.dart` with `createTestRealtime()` helper function for common test setup.
- All 18 tests pass successfully.
