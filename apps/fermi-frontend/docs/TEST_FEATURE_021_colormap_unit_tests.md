## TEST_FEATURE_021 – `colormap` score-to-color unit tests

### Scope

Implement tests for score-to-color mapping as described in `docs/TESTS.md` under:

- **Unit Tests → Utilities → `Score to Color`**

Cover mapping of low/high scores, interpolation, and edge cases.

### Code / Files Involved

- `lib/theme/colormap.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Unit Tests → Utilities → `Score to Color`”**
- `docs/TESTING_GUIDELINES.md`
  - Unit test basics.

### Fixtures & Helpers

- No external fixtures required; use sample score values (including extremes) directly in tests.

### Tasks for this Feature

1. Create `test/unit/utils/colormap_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Color Mapping
3. Verify:
   - Low scores map to “danger” colors.
   - High scores map to “success” colors.
   - Intermediate scores interpolate correctly.
   - Edge scores behave as documented (0%, 100%).

### Done Checklist

- [x] `colormap_test.dart` created and covers low/high/intermediate/edge scores.
- [x] Tests are deterministic and match visual expectations used in the app.
- [x] `fvm flutter test test/unit/utils/colormap_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- Tests were split into three files in `test/unit/utils/colormap/` folder to keep each file under 300 lines:
  - `percentile_to_color_test.dart` (125 lines) - Tests for `percentileToColor` function
  - `score_to_color_test.dart` (152 lines) - Tests for `scoreToColor` function
  - `normalize_to_unit_interval_test.dart` (111 lines) - Tests for `normalizeToUnitInterval` helper function

- Color thresholds: The color mapping uses linear interpolation (lerp) between `danger` and `success` colors from `AppTheme`. The thresholds are:
  - **Low scores (0% or min score)**: Maps to `danger` color (defined in `AppTheme.defaultTheme()` as `hsl(9 26% 64%)` - reddish)
  - **High scores (100% or max score)**: Maps to `success` color (defined in `AppTheme.defaultTheme()` as `hsl(146 17% 59%)` - greenish)
  - **Intermediate scores**: Linearly interpolated between danger and success using `Color.lerp(danger, success, t)` where `t` is the normalized value in [0,1]
  - The normalization is handled by `normalizeToUnitInterval` which clamps values outside the range to [0,1]

- All edge cases are covered: values below min, above max, exact min/max, and the special case where min == max (returns 0.0)

- Both functions accept an optional `theme` parameter to allow custom color schemes, which is tested with custom themes
