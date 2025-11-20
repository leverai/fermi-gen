## TEST_FEATURE_014 – `AuthService` unit tests

### Scope

Implement `AuthService` unit tests as described in `docs/TESTS.md` under:

- **Unit Tests → Services → `AuthService`**

Cover token exchange, token refresh, and state management (last round settings, refresh flags).

### Code / Files Involved

- `lib/services/auth_service.dart`
- Any related configuration or storage mechanisms (e.g., shared preferences, in-memory storage).

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Services → `AuthService`”**
- `docs/TESTING_GUIDELINES.md`
  - Unit testing with mocks.

### Fixtures & Helpers

- Use `MockApiService` or other relevant mocks from `test/helpers/mock_factories.dart` if `AuthService` delegates to them.
- Avoid real Firebase; use mocks or abstractions instead.

### Tasks for this Feature

1. Create `test/unit/services/auth_service_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Token Exchange
   - Token Refresh
   - State Management
3. Assert that:
   - Tokens and user objects are stored/updated as expected.
   - Failure conditions return proper flags and do not leave inconsistent state.
4. Ensure no real network/Firebase calls.

### Done Checklist

- [x] `auth_service_test.dart` created with all specified test groups.
- [x] All external interactions are mocked.
- [x] `fvm flutter test test/unit/services/auth_service_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Refactoring for testability**: `AuthService` was refactored to accept optional `FirebaseAuth` and `http.Client` dependencies via constructor parameters. The default constructor (no parameters) maintains backward compatibility by using `FirebaseAuth.instance` and a new `http.Client()` instance.

- **Mocking approach**: Custom mocks were created for `FirebaseAuth` and `User` using `mocktail` since `firebase_auth_mocks` doesn't integrate well with `mocktail`'s `when()` syntax. The mocks are defined in the test file itself.

- **Token storage**: Access tokens are stored directly in the `AuthService` instance as a public field. User objects are parsed from API responses and stored in `currentUser`. Locale is extracted from user objects when present.

- **Error handling**: Both `exchangeToken()` and `refreshAccessToken()` return `false` on failure and do not throw exceptions. Network errors are caught and logged via `debugPrint()`.

- **Token refresh fallback**: When refresh returns 401, the service automatically falls back to `exchangeToken()` using the Firebase ID token.
