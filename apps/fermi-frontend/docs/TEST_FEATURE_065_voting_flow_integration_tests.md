## TEST_FEATURE_065 – `Voting Flow` integration tests

### Scope

Implement `Voting Flow` integration tests as described in `docs/TESTS.md` under:

- **Integration Tests → Scenarios → `Voting Flow`**

Cover upvote, downvote, toggle, and persistence behavior across sessions.

### Code / Files Involved

- `lib/main.dart`
- Widgets:
  - `lib/widgets/question_widget.dart`
  - `lib/widgets/animated_like_dislike.dart`
- Services:
  - `lib/services/api_service.dart`
  - `lib/services/game_realtime.dart` / `lib/services/firestore_game_realtime.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Integration Tests → Scenarios → `Voting Flow`”**
- `docs/TESTING_GUIDELINES.md`
  - Integration test guidance.

### Fixtures & Helpers

- Use:
  - Question fixtures with initial vote state from `question_data.dart`.
  - Emulator helpers to verify persisted vote state (e.g., via Firestore documents).

### Tasks for this Feature

1. Create `test/integration/scenarios/voting_flow_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Upvote
   - Downvote
   - Toggle Votes
3. In tests:
   - Simulate taps on vote buttons using `ValueKey`s.
   - Confirm counts, state, and persistence are reflected in both UI and emulator state.

### Done Checklist

- [ ] `voting_flow_test.dart` created with all required groups.
- [ ] Tests validate persistent vote state via emulators.
- [ ] `fvm flutter test test/integration/scenarios/voting_flow_test.dart` passes with emulators running.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- _Note any assumptions about how vote state is stored (e.g., per-user doc structure) and how tests locate that in the emulator._
