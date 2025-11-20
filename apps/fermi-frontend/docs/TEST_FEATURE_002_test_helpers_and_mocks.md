## TEST_FEATURE_002 – Test helpers & mock factories

### Scope

Create reusable **helpers and mocks** that all other tests can rely on:

- `test/helpers/mock_factories.dart`
- `test/helpers/test_helpers.dart`
- `test/helpers/firebase_emulator_setup.dart`

These correspond to the **Mock Factories** and **Test Setup** sections in `docs/TESTS.md` and `docs/TESTING_GUIDELINES.md`.

### Code / Files Involved

- New helper files:
  - `test/helpers/mock_factories.dart`
  - `test/helpers/test_helpers.dart`
  - `test/helpers/firebase_emulator_setup.dart`
- Services & realtime interfaces to mock:
  - `lib/services/api_service.dart`
  - `lib/services/auth_service.dart`
  - `lib/services/game_realtime.dart`
  - `lib/services/firestore_game_realtime.dart`
- For integration setup:
  - Use Firebase emulator host/port values from `docs/TESTS.md`.

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Mock Factories”** section.
  - **“Integration Tests / Test Setup”** section.
- `docs/TESTING_GUIDELINES.md`
  - **Section 1: Unit Tests (mocktail usage)**.
  - **Section 4: Integration Tests (Firebase emulator usage)**.
- `docs/TEST_FIXTURES.md`
  - Sections for `mock_factories.dart`, `test_helpers.dart`, `firebase_emulator_setup.dart`.

### Fixtures & Helpers

Implement the following patterns:

- `mock_factories.dart`:
  - `class MockApiService extends Mock implements ApiService { ... }`
  - `class MockAuthService extends Mock implements AuthService { ... }`
  - `class MockGameRealtime extends Mock implements GameRealtime { ... }`
  - `class MockFirestoreGameRealtime extends Mock implements FirestoreGameRealtime { ... }`
  - Any necessary `Fake`/fallback value registrations.
- `test_helpers.dart`:
  - Common wrappers for widget tests (e.g., `pumpWithMaterialApp`, `pumpMainScreen`).
  - Utilities for waiting on animations (`pumpAndSettle` helpers).
- `firebase_emulator_setup.dart`:
  - Functions to connect `FirebaseAuth` and `FirebaseFirestore` to emulators.
  - Helpers to clean up data between tests.

### Tasks for this Feature

1. Implement `mock_factories.dart` using `mocktail` and the patterns in `TESTING_GUIDELINES.md`.
2. Implement `test_helpers.dart` with:
   - A minimal, reusable app wrapper for widget tests.
   - Helpers to set locales and theming if needed.
3. Implement `firebase_emulator_setup.dart` for integration tests as described in `docs/TESTS.md`.
4. Update `docs/TEST_FIXTURES.md`:
   - Document available mocks and helpers.
5. Add one small unit test or widget test that uses these helpers to verify they integrate correctly.

### Done Checklist

- [x] `mock_factories.dart` exposes reusable mocks for key services.
- [x] `test_helpers.dart` provides shared widget test wrappers and utilities.
- [x] `firebase_emulator_setup.dart` connects to emulators and is ready for integration tests.
- [x] `docs/TEST_FIXTURES.md` updated accordingly.
- [x] A small sanity test confirms the helpers work as expected.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Mock Factories**: All mocks use `mocktail` and follow the patterns in `TESTING_GUIDELINES.md`. The `registerFallbackValues()` function should be called in `setUpAll()` when using `any()` matchers. Currently only `AnswerValue` is registered as a fallback; additional types may need to be added as tests are written.

- **Test Helpers**: The widget test helpers wrap widgets in `MaterialApp` with the app's theme extensions (`AppTheme` and `AppFont`). This ensures consistent theming across all widget tests. The helpers support optional locale parameters for testing internationalization.

- **Firebase Emulator Setup**: The emulator setup automatically detects the platform (Android uses '10.0.2.2', others use 'localhost'). Default ports match the documentation (Firestore: 8080, Auth: 9099). The cleanup function currently only signs out users; for more thorough cleanup, future features may need to call the emulator's REST API or use Firebase Admin SDK.

- **State Management**: The helpers assume widgets are tested in isolation with mocked dependencies. For tests that need state management (e.g., Provider, Riverpod), additional helpers may need to be added in future features.

- **Sanity Test**: Created `test/helpers/helpers_test.dart` which verifies all mocks can be instantiated and all helper functions work correctly. All tests pass.
