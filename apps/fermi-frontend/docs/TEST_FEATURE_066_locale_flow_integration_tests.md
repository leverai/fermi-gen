## TEST_FEATURE_066 – `Locale Flow` integration tests

### Scope

Implement `Locale Flow` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Locale Flow`**

Cover locale selection, unit updates, persistence, and correct unit display in the UI.

### Code / Files Involved

- `lib/main.dart`
- Widgets:
  - `lib/widgets/unit_locale_selector.dart`
  - `lib/widgets/answer_widget.dart`
- Services:
  - `lib/services/api_service.dart`
  - `lib/services/auth_service.dart`
  - `lib/services/game_realtime.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Locale Flow`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration testing guidance.
- `docs/TEST_FIXTURES.md`
  - Unit mappings and locale-related fixtures.

### Fixtures & Helpers

- Use:
  - `question_data.dart` for US/EU unit variants.
  - Emulator helpers to verify persisted locale (e.g., in user documents).

### Tasks for this Feature

1. Create `test/integration/scenarios/locale_flow_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Locale Selection
   - Unit Display
3. Simulate:
   - Switching between locales via UI.
   - Verifying unit options and abbreviations update in `AnswerWidget`.
   - Reloading/restarting the app (or simulating it) to ensure persistence.

### Done Checklist

- [ ] `locale_flow_test.dart` created with all required groups.
- [ ] Tests verify both UI and backend locale persistence.
- [ ] `fvm flutter test test/integration/scenarios/locale_flow_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Document any helpers you created for changing locales and checking unit display across the app._
