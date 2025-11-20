## TEST_FEATURE_001 – Core fixtures (`game_snapshots`, `question_data`, `player_data`)

### Scope

Implement the core fixtures described in `docs/TESTS.md` under **“Test Data and Fixtures”**:

- `test/fixtures/game_snapshots.dart`
- `test/fixtures/question_data.dart`
- `test/fixtures/player_data.dart`

These fixtures will be reused across unit, widget, and integration tests.

### Code / Files Involved

- New fixture files:
  - `test/fixtures/game_snapshots.dart`
  - `test/fixtures/question_data.dart`
  - `test/fixtures/player_data.dart`
- Model references:
  - `lib/models/game_config.dart`
  - `lib/models/player_stats.dart`
  - `lib/screens/question_v2/models/question_state.dart`
  - Any DTOs used by `GameRealtime` / `FirestoreGameRealtime` where needed.

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Test Data and Fixtures”** section.
- `docs/TESTING_GUIDELINES.md`
  - **Unit tests** and **widget tests** sections (for how fixtures should be used).
- `docs/TEST_FIXTURES.md`
  - This feature should **fully populate** the entries for the three core fixture files.

### Fixtures & Helpers

You should implement:

- Factories for common game states:
  - Lobby, in-question, reveal, finished, review mode.
- Question payloads:
  - Include text, tags, units, correct answers, and example percentiles where relevant.
- Player data:
  - Different host/self/other combinations and score distributions.

Fixtures MUST:

- Be **pure Dart data** (no network, no Firebase, no IO).
- Be safe to use in both unit and widget tests.

### Tasks for this Feature

1. Implement `game_snapshots.dart` factories as described in `docs/TESTS.md`.
2. Implement `question_data.dart` with reusable sample questions and units.
3. Implement `player_data.dart` with reusable player lists and score setups.
4. For each file, update `docs/TEST_FIXTURES.md`:
   - Document key factory functions and intended usage.
5. Add a small unit test file (e.g., `test/unit/fixtures/fixtures_sanity_test.dart`) to:
   - Ensure factories instantiate without throwing.
   - Catch basic regressions if fixture shapes change.

### Done Checklist

- [x] Core fixture files created and exported as pure Dart helpers.
- [x] Fixtures cover the states outlined in `docs/TESTS.md`.
- [x] `docs/TEST_FIXTURES.md` updated with factory names and purposes.
- [x] Fixture sanity tests exist and pass.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Implementation completed**: All three core fixture files have been created with comprehensive factory functions.
- **Game snapshots**: Covers all game states (lobby, question, finished, aborted) with single and multi-player scenarios. Supports customization of players, question counts, durations, and progress tracking.
- **Question data**: Provides 5 sample questions across different categories with US/EU locale support, correct answers, and unit mappings. Includes unitless question example.
- **Player data**: Comprehensive player summaries and states for single-player, multi-player, tied scores, and inactive players. Includes score distributions, percentiles, and progress tracking.
- **Limitations/Extensions**:
  - Fixtures use default values but allow full customization via optional parameters.
  - Could be extended with more edge cases (e.g., very large player counts, extreme scores, missing data scenarios).
  - Question data could be extended with more categories and difficulty levels if needed.
- **Sanity tests**: All 31 sanity tests pass, verifying that all factories instantiate correctly.
