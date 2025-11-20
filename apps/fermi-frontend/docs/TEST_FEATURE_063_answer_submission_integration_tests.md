## TEST_FEATURE_063 – `Answer Submission Flow` integration tests

### Scope

Implement `Answer Submission Flow` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Answer Submission Flow`**

Cover manual submission, auto-submission on deadline, answer validation, and unit handling.

### Code / Files Involved

- `lib/main.dart`
- `lib/screens/question_v2/question_screen_v2.dart`
- Widgets:
  - `lib/widgets/answer_widget.dart`
  - `lib/screens/question_v2/widgets/submit_bar.dart`
- Services:
  - `lib/services/question_deadline_timer.dart`
  - `lib/services/firestore_game_realtime.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Answer Submission Flow`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration tests, timing, and emulator usage.
- `docs/TEST_FIXTURES.md`
  - Question and unit fixtures.

### Fixtures & Helpers

- Use:
  - `question_data.dart` for unitful and unitless questions.
  - Emulator setup helpers to simulate deadline and submission events.

### Tasks for this Feature

1. Create `test/integration/scenarios/answer_submission_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Manual Submission
   - Auto-Submission
   - Answer Validation
3. Simulate:
   - User entering an answer and tapping submit.
   - Deadline expiration causing auto-submit.
   - Unit mapping and unitless behavior using fixtures.

### Done Checklist

- [ ] `answer_submission_test.dart` created with all required groups.
- [ ] Tests validate both manual and auto-submission paths using emulators.
- [ ] `fvm flutter test test/integration/scenarios/answer_submission_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Note any abstractions used for deadline timers in integration tests and how they interplay with the controller logic._
