## TEST_FEATURE_047 – `GameCarousel` widget tests

### Scope

Implement `GameCarousel` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `GameCarousel`**

Cover rendering, navigation, and live vs review mode behavior.

### Code / Files Involved

- `lib/screens/question_v2/widgets/game_carousel.dart`
- `lib/screens/question_v2/widgets/game_card.dart`

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `GameCarousel`”**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests and animations.
- `docs/TEST_FIXTURES.md`
  - `question_data.dart` and game snapshot fixtures.

### Fixtures & Helpers

- Use fixtures to provide lists of questions and states to the carousel.

### Tasks for this Feature

1. Create `test/widget/widgets/game_carousel_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Rendering
   - Navigation
3. Verify:
   - The correct question is shown at each index.
   - Dots indicator updates on page change.
   - Programmatic navigation animates correctly.
   - In live (non-review) mode, swipe navigation is prevented when required.

### Done Checklist

- [x] `game_carousel_test.dart` created with all required groups.
- [x] Tests cover both review and live modes, including swipe prevention.
- [x] `fvm flutter test test/widget/widgets/game_carousel/` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Test Organization**: Tests have been split into multiple files within the `game_carousel/` folder to keep each file under 300 lines:
  - `rendering_test.dart` - Rendering tests (4 tests)
  - `navigation_test.dart` - Navigation tests (7 tests)
  - `test_helpers.dart` - Shared helper functions for building test widgets

- **Live vs Review Mode**: The carousel distinguishes live vs review mode via the `enableUserSwipe` parameter:
  - `enableUserSwipe = false` (live mode): Swipe navigation is prevented via `NeverScrollableScrollPhysics`
  - `enableUserSwipe = true` (review mode): Swipe navigation is allowed via `BouncingScrollPhysics`
  - The dots indicator also changes color based on this parameter (highlight color for live mode, primary color for review mode)

- **Swipe Testing**: Full swipe gesture testing is done at the screen level (QuestionScreenV2 tests). The widget tests verify that:
  - The `enableUserSwipe` property is correctly set
  - `onPageChanged` callback is called when navigation occurs (via programmatic navigation)
  - Swipe prevention works by verifying dots position doesn't change when swiping in live mode

- **Test Coverage**: All 11 tests passing:
  - Rendering: 4 tests (carousel display, dots indicator, correct question at index, itemCount handling)
  - Navigation: 7 tests (dots update, onPageChanged callback, programmatic navigation, live mode prevention, review mode allowance, dots color, jumpToPage)
