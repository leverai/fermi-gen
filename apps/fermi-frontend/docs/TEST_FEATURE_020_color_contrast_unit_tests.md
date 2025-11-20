## TEST_FEATURE_020 – `color_contrast` utilities unit tests

### Scope

Implement tests for color contrast utilities as described in `docs/TESTS.md` under:

- **Unit Tests → Utilities → `Color Utilities`**

Cover contrast calculation and appropriate foreground color selection.

### Code / Files Involved

- `lib/utils/color_contrast.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Utilities → `Color Utilities`”**
- `docs/TESTING_GUIDELINES.md`
  - Unit test basics.

### Fixtures & Helpers

- No external fixtures required; tests can use literal color values.

### Tasks for this Feature

1. Create `test/unit/utils/color_contrast_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Contrast Calculation
3. Verify:
   - Contrast ratio calculation correctness for known inputs.
   - White vs black foreground selection for dark/light backgrounds.
   - Edge case handling.

### Done Checklist

- [x] `color_contrast_test.dart` created with all expected cases.
- [x] Tests are deterministic and pure.
- [x] `fvm flutter test test/unit/utils/color_contrast_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Test Coverage**: Implemented comprehensive tests for both `bestOn()` and `pickContrastingTextColor()` functions:
  - `bestOn()`: Tests contrast ratio calculation, dark/light background handling, and edge cases
  - `pickContrastingTextColor()`: Tests luminance-based selection, preferred color parameters, and edge cases
- **Test Structure**: Tests are organized into two groups within the "Contrast Calculation" group:
  - `bestOn` group: 4 tests covering contrast calculation, dark/light backgrounds, and edge cases
  - `pickContrastingTextColor` group: 8 tests covering dark/light backgrounds, preferred colors, and edge cases
- **Edge Cases Covered**: Pure black/white, near-black/near-white, medium gray (luminance ~0.5), very dark/light colors, and near-transparent colors
- **No Tolerance Needed**: All assertions use exact color comparisons (Color equality) since the functions return discrete Color values (Colors.white or Colors.black) or specific Color instances. No floating-point tolerance needed.
- **File Size**: Test file is 245 lines, well under the 300-line limit.
- **All Tests Pass**: All 12 tests pass successfully.
