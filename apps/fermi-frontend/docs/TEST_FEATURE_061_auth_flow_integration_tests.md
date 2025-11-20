## TEST_FEATURE_061 – `Auth Flow` integration tests

### Scope

Implement `Auth Flow` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Authentication Flow`**

Cover sign in, token exchange, token refresh, and sign out behavior end-to-end.

### Code / Files Involved

- `lib/main.dart`
- Auth-related UI (onboarding/login screens):
  - `lib/screens/onboarding_screen.dart` (and any login-related widgets)
- Services:
  - `lib/services/auth_service.dart`
  - `lib/services/api_service.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Authentication Flow`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration tests with Firebase emulators.
- `docs/TEST_FIXTURES.md`
  - `firebase_emulator_setup.dart` helpers.

### Fixtures & Helpers

- Use:
  - Emulator setup helpers for Auth emulator.
  - Test users seeded into the Auth emulator (via setup utilities or pre-defined credentials).

### Tasks for this Feature

1. Create `test/integration/scenarios/auth_flow_test.dart`.
2. Set up emulator connections for Auth and Firestore if needed.
3. Implement groups from `docs/TESTS.md`:
   - Sign In
   - Token Refresh
   - Sign Out
4. Use widget keys for login fields and buttons, updating production code to add `ValueKey`s where necessary.

### Done Checklist

- [ ] `auth_flow_test.dart` created with all required groups.
- [ ] Tests use emulators and mock backend behavior only via emulated services.
- [ ] `fvm flutter test test/integration/scenarios/auth_flow_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Note any assumptions made about login flows (e.g., pre-seeded users, test credentials) and where they are configured._
