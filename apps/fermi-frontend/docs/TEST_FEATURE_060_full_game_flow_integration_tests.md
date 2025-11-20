## TEST_FEATURE_060 – `Full Game Flow` integration tests

### Scope

Implement `Full Game Flow` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Flows → `Full Game Flow`**

Cover end-to-end game behavior for:

- Single-player private game.
- Multi-player game (host + others).
- Public and private flows as described.

These tests MUST use Firebase emulators (no real backend).

### Code / Files Involved

- App entry:
  - `lib/main.dart`
- Screens:
  - `lib/screens/main/main_screen.dart`
  - `lib/screens/lobby/lobby_screen.dart`
  - `lib/screens/question_v2/question_screen_v2.dart`
- Services:
  - `lib/services/auth_service.dart`
  - `lib/services/api_service.dart`
  - `lib/services/firestore_game_realtime.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Flows → `Full Game Flow`”**
  - **“Integration Tests → Test Setup”**
- `docs/TESTING_GUIDELINES.md`
  - Integration test section and emulator usage.
- `docs/TEST_FIXTURES.md`
  - `firebase_emulator_setup.dart` helpers.

### Fixtures & Helpers

- Use:
  - `test/helpers/firebase_emulator_setup.dart` to connect to emulators.
  - Fixture data to seed Firestore and Auth emulator where needed.

### Tasks for this Feature

1. Create `test/integration/flows/full_game_flow_test.dart`.
2. Set up integration binding and emulator configuration as per `TESTING_GUIDELINES.md`.
3. Implement groups from `docs/TESTS.md`:
   - Happy Path: Single Player
   - Happy Path: Multi-Player
   - Public Game Flow
   - Private Game Flow
4. Use Firestore emulator writes in the test to simulate backend events (e.g., question reveal).
5. Ensure cleanup between tests to avoid state leakage.

### Done Checklist

- [ ] `full_game_flow_test.dart` created with all required groups.
- [ ] Tests run against emulators and not real Firebase.
- [ ] `fvm flutter test test/integration/flows/full_game_flow_test.dart` passes when emulators are running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Document any utilities you add for seeding emulator data and how future flows should reuse them._
