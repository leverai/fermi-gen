## TEST_FEATURE_000 – Testing infrastructure & directory scaffold

### Scope

Set up the **initial Flutter testing infrastructure** for `@fermi-frontend` so that all later feature requests can add tests without reworking the basics.

This corresponds to the general structure and expectations described throughout `docs/TESTS.md` and `docs/TESTING_GUIDELINES.md`.

### Code / Files Involved

- `pubspec.yaml` (`dev_dependencies` for testing)
- New directories to create:
  - `test/unit/`
  - `test/widget/`
  - `test/integration/`
  - `test/fixtures/`
  - `test/helpers/`
- Optional but recommended:
  - `test/flutter_test_config.dart` (for golden tests as per `TESTING_GUIDELINES.md`)

### Related Docs & Sections

- `docs/TESTING_GUIDELINES.md`
  - **“General Guidelines (Must-Follow Rules)”**
  - **“Section 1: Unit Tests”**
  - **“Section 2: Widget Tests”**
  - **“Section 3: Golden Tests”**
  - **“Section 4: Integration Tests”**
- `docs/TESTS.md`
  - Overall **Directory Structure** section.

### Fixtures & Helpers

- This feature does **not** implement fixtures yet, but you MUST create:
  - Empty placeholder files or README comments in:
    - `test/fixtures/`
    - `test/helpers/`
- Do **not** add real factories here; that is handled by:
  - `TEST_FEATURE_001_core_fixtures`
  - `TEST_FEATURE_002_test_helpers_and_mocks`

### Tasks for this Feature

1. **Configure testing dependencies**
   - Ensure `pubspec.yaml` has all required `dev_dependencies` from `TESTING_GUIDELINES.md`:
     - `flutter_test`, `integration_test`, `mocktail`, `firebase_auth_mocks`, `fake_cloud_firestore`, `golden_toolkit` (or confirm they exist).
2. **Create test directory structure**
   - Create the full directory tree under `test/` as shown in `docs/TESTS.md`.
3. **Add Flutter test config (optional but preferred)**
   - Add `test/flutter_test_config.dart` to configure font loading for golden tests, as per the guidelines.
4. **Run a smoke test**
   - Add a trivial sample test (e.g., in `test/unit/sample_sanity_test.dart`).
   - Run `fvm flutter test` and ensure everything passes.
   - You may delete or keep the sample test after confirming the setup (leave a note below).

### Done Checklist

- [ ] `pubspec.yaml` has all required testing dev dependencies.
- [ ] `test/` directory structure matches `docs/TESTS.md`.
- [ ] (Optional) `test/flutter_test_config.dart` created and wired for golden tests.
- [ ] `fvm flutter test` succeeds with at least one trivial test.
- [ ] Any sample/sanity tests are either removed or documented in continuity notes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Dependencies**: Updated `firebase_auth_mocks` to `^0.14.1` and `fake_cloud_firestore` to `^3.1.0` to be compatible with `firebase_core ^3.14.0` and `cloud_firestore ^5.6.9`. Note that `golden_toolkit` is marked as discontinued, but it's still functional for now.
- **Sample Test**: Created `test/unit/sample_sanity_test.dart` as a smoke test. This can be kept for reference or removed later - it serves as a good example of the AAA pattern.
- **Directory Structure**: All directories created as specified in `docs/TESTS.md`. Placeholder files created in `test/fixtures/` and `test/helpers/` to be replaced by actual implementations in TEST_FEATURE_001 and TEST_FEATURE_002.
- **Flutter Test Config**: Created `test/flutter_test_config.dart` for golden test support with font loading. This is wired up and ready for use.
- **Verification**: All tests pass successfully with `fvm flutter test test/unit/sample_sanity_test.dart`.
