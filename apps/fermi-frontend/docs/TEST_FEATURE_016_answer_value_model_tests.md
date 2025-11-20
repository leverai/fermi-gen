## TEST_FEATURE_016 – `AnswerValue` model tests

### Scope

Implement tests for the `AnswerValue` model as described in `docs/TESTS.md` under:

- **Unit Tests → Models → `AnswerValue`**

Cover equality, hashCode, and string representation.

### Code / Files Involved

- `lib/models/answer_value.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Models → `AnswerValue`”**
- `docs/TESTING_GUIDELINES.md`
  - Unit test basics (AAA, naming, grouping).

### Fixtures & Helpers

- No external fixtures required; these tests can construct `AnswerValue` directly.

### Tasks for this Feature

1. Create `test/unit/models/answer_value_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Equality
   - Hash Code
   - String Representation
3. Ensure:
   - Equal objects compare equal and share hash codes.
   - Different fields produce inequality and distinct hashes.
   - `toString` output is stable and human-readable as expected by the app.

### Done Checklist

- [x] `answer_value_test.dart` created and covers equality/hash/toString.
- [x] Tests are deterministic and do not rely on external state.
- [x] `fvm flutter test test/unit/models/answer_value_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **toString format**: The `toString()` method follows the format `'AnswerValue(number: $number, om: $orderOfMagnitude, unit: $unit)'`. This format is stable and human-readable. Future changes to this format should update the corresponding test in `test/unit/models/answer_value_test.dart`.
- **Test coverage**: All equality, hashCode, and toString behaviors are covered. The tests verify that:
  - Equal objects (same number, OM, unit) compare equal and share hash codes
  - Different fields produce inequality and distinct hashes
  - toString output matches the expected format for various combinations including empty strings for OM and unit
