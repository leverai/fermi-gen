## TEST_FEATURE_067 – `Error Handling` integration tests

### Scope

Implement `Error Handling` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Error Handling`**

Cover network errors, Firestore errors, and state errors, ensuring the UI responds gracefully.

### Code / Files Involved

- `lib/main.dart`
- Screens:
  - `lib/screens/main/main_screen.dart`
  - `lib/screens/lobby/lobby_screen.dart`
  - `lib/screens/question_v2/question_screen_v2.dart`
- Services:
  - `lib/services/api_service.dart`
  - `lib/services/firestore_game_realtime.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Error Handling`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration test guidance, error path coverage.

### Fixtures & Helpers

- Use:
  - Emulator helpers to simulate missing documents, permission errors, and invalid state.
  - API stubbing (if available) or emulator-backed endpoints that intentionally fail.

### Tasks for this Feature

1. Create `test/integration/scenarios/error_handling_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Network Errors
   - Firestore Errors
   - State Errors
3. Simulate each error via emulators or controlled test hooks and verify:
   - User-facing error messages/snackbars.
   - Retry behavior and timeouts where specified.
   - That the app does not crash or get stuck in inconsistent states.

### Done Checklist

- [ ] `error_handling_test.dart` created with all required groups.
- [ ] Tests simulate errors via emulators or controlled stubs, not random failures.
- [ ] `fvm flutter test test/integration/scenarios/error_handling_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Note any additional hooks or configuration you added to reliably simulate error conditions in a deterministic way._
