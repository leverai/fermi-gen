## TEST_FEATURE_062 – `Real-time Synchronization` integration tests

### Scope

Implement `Real-time Synchronization` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Real-time Synchronization`**

Verify UI updates when game state, questions, answers, and scores change in Firestore.

### Code / Files Involved

- `lib/main.dart`
- Screens:
  - `lib/screens/lobby/lobby_screen.dart`
  - `lib/screens/question_v2/question_screen_v2.dart`
- Services:
  - `lib/services/firestore_game_realtime.dart`
  - `lib/services/game_realtime.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Real-time Synchronization`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration test and emulator guidance.
- `docs/TEST_FIXTURES.md`
  - Emulator setup helpers and snapshot fixtures.

### Fixtures & Helpers

- Use:
  - `firebase_emulator_setup.dart` to connect to emulators.
  - Fixture builders to seed games and players in Firestore emulator.

### Tasks for this Feature

1. Create `test/integration/scenarios/realtime_sync_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Game State Updates
   - Multi-Player Synchronization
   - Connection Handling
3. In each test, simulate backend changes via Firestore emulator writes and confirm UI updates accordingly.

### Done Checklist

- [ ] `realtime_sync_test.dart` created with all required groups.
- [ ] Tests use emulators and not mocks for realtime.
- [ ] `fvm flutter test test/integration/scenarios/realtime_sync_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Document any polling/timeout strategies you used to wait for UI updates and how to tune them if tests become flaky._
