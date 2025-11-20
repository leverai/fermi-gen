## TEST_FEATURE_042 – `QuestionWidget` widget tests

### Scope

Implement `QuestionWidget` widget tests as described in `docs/TESTS.md` under:

- **Widget Tests → Widgets → `QuestionWidget`**

Cover rendering, voting behavior, and copy-to-clipboard interactions.

### Code / Files Involved

- `lib/widgets/question_widget.dart`
- Supporting widgets:
  - `lib/widgets/tag_widget.dart`
  - `lib/widgets/animated_like_dislike.dart`
  - `lib/widgets/submitted_answer_chip.dart` (if used)

### Related Docs & Sections

- `docs/TESTS.md`
  - **“Widget Tests → Widgets → `QuestionWidget`”**
- `docs/TESTING_GUIDELINES.md`
  - Widget tests and keys.

### Fixtures & Helpers

- Use `question_data.dart` for sample questions, tags, and initial vote states.
- Wrap the widget with `MaterialApp` and any required providers using `test/helpers/test_helpers.dart`.

### Tasks for this Feature

1. Create `test/widget/widgets/question_widget_test.dart`.
2. Implement groups from `docs/TESTS.md`:
   - Rendering
   - Voting
   - Copy Feature
3. Ensure:
   - Voting callbacks (`onUpvote`, `onDownvote`) are invoked correctly.
   - Upvote count and visual state update properly.
   - Copy behavior (long press and icon tap) interacts with clipboard APIs in a test-safe way (use mocks/fakes).

### Done Checklist

- [x] `question_widget_test.dart` created with all required groups.
- [x] Clipboard and voting dependencies are abstracted/mocked appropriately.
- [x] `fvm flutter test test/widget/widgets/question_widget_test.dart` passes.

### Out of Scope

- Do not refactor or modify unrelated production code or tests beyond what is needed for this feature.
- Do not change public APIs unless strictly required for testability; prefer injecting/mocking dependencies instead.
- Do not implement tests outside the groups listed in the **Scope** / **Tasks for this Feature** sections.

### Continuity Notes

- **Test file created**: Split into three files in `test/widget/widgets/question_widget/`:
  - `question_widget_rendering_test.dart` - Rendering tests
  - `question_widget_voting_test.dart` - Voting behavior tests
  - `question_widget_copy_test.dart` - Copy feature tests
- **Copy functionality**: `QuestionWidget` is a presentational component and does NOT have built-in copy functionality by design. Copy functionality is handled by the parent `GameCard` widget, which wraps `QuestionWidget` in an `InkWell` with `onLongPress`. The copy tests verify that `QuestionWidget` doesn't interfere with parent gesture handling and doesn't implement copy functionality itself.
- **Voting tests**: All voting tests pass and verify callback invocation, state updates, and count changes using `LikeButton` widgets from the `like_button` package.
- **Test keys**: No test-specific keys were needed. The `likeWidgetKey` parameter is available but not required for tests.
- **Architecture note**: The test requirements in `TESTS.md` list copy functionality tests for `QuestionWidget`, but this is a documentation issue. Copy functionality should be tested at the `GameCard` level (TEST_FEATURE_043), not at the `QuestionWidget` level.
