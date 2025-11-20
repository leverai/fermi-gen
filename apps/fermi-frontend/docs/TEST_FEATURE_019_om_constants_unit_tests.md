## TEST_FEATURE_019 – `OM constants` unit tests

### Scope

Implement tests for the OM (order-of-magnitude) constants/utilities described in `docs/TESTS.md` under:

- **Unit Tests → Utilities → `OM Constants`**

Cover multiplier lookup behavior and edge cases.

### Code / Files Involved

- `lib/utils/om_constants.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Utilities → `OM Constants`”**
- `docs/TESTING_GUIDELINES.md`
  - Unit test basics.

### Fixtures & Helpers

- No external fixtures required; tests can use literal OM values and expected multipliers.

### Tasks for this Feature

1. Create `test/unit/utils/om_constants_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Multiplier Lookup
3. Verify:
   - Correct multiplier for each valid OM.
   - Returns `1` for empty or unknown OM strings.

### Done Checklist

- [x] `om_constants_test.dart` created and covers all multiplier behaviors.
- [x] Tests are pure and deterministic.
- [x] `fvm flutter test test/unit/utils/om_constants_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- All OM values documented in `orderOfMagnitudeSymbols` are covered: `''`, `'K'`, `'M'`, `'B'`, `'T'`, `'Qa'`.
- Tests verify the lookup pattern used in production code (`orderOfMagnitudeMultipliers[om] ?? 1`).
- Additional tests were added to verify consistency between `orderOfMagnitudeSymbols` and `orderOfMagnitudeMultipliers`, and to verify that multipliers follow the expected power-of-1000 pattern.
- No undocumented OM values were discovered in production code.
