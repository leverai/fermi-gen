## Flutter Frontend Testing Roadmap

This roadmap turns `docs/TESTS.md` into a set of **bite-sized, LLM-friendly feature requests**.
Agents should:

- Pick the **next unchecked item** below.
- Open the linked **feature request** file.
- Follow `docs/TESTING_GUIDELINES.md`, `docs/TESTS.md`, and the feature request instructions.
- Update the **checkbox** and **continuity notes** when done.

> All new tests and fixtures MUST be documented according to `docs/TESTING_GUIDELINES.md` and `docs/TEST_FIXTURES.md`.

---

### 0. Foundational Setup

- [x] [TEST_FEATURE_000 – Testing infrastructure & directory scaffold](./TEST_FEATURE_000_testing_infrastructure.md)
- [x] [TEST_FEATURE_001 – Core fixtures (`game_snapshots`, `question_data`, `player_data`)](./TEST_FEATURE_001_core_fixtures.md)
- [x] [TEST_FEATURE_002 – Test helpers & mock factories](./TEST_FEATURE_002_test_helpers_and_mocks.md)

---

### 1. Unit Tests – Controllers, Services, Models, Utilities

- [x] [TEST_FEATURE_010 – `MainScreenController` unit tests](./TEST_FEATURE_010_main_screen_controller_unit_tests.md)
- [x] [TEST_FEATURE_011 – `LobbyScreenController` unit tests](./TEST_FEATURE_011_lobby_screen_controller_unit_tests.md)
- [x] [TEST_FEATURE_012A – `QuestionScreenV2Controller` state & index unit tests](./TEST_FEATURE_012A_question_screen_v2_controller_state_and_index_unit_tests.md)
- [x] [TEST_FEATURE_012B – `QuestionScreenV2Controller` answer & timers unit tests](./TEST_FEATURE_012B_question_screen_v2_controller_answer_and_timers_unit_tests.md)
- [x] [TEST_FEATURE_012C – `QuestionScreenV2Controller` reveal, players & review unit tests](./TEST_FEATURE_012C_question_screen_v2_controller_reveal_players_review_unit_tests.md)
- [x] [TEST_FEATURE_013 – `ApiService` unit tests](./TEST_FEATURE_013_api_service_unit_tests.md)
- [x] [TEST_FEATURE_014 – `AuthService` unit tests](./TEST_FEATURE_014_auth_service_unit_tests.md)
- [x] [TEST_FEATURE_015 – `GameRealtime` & `FirestoreGameRealtime` unit tests](./TEST_FEATURE_015_game_realtime_unit_tests.md)
- [x] [TEST_FEATURE_016 – `AnswerValue` model tests](./TEST_FEATURE_016_answer_value_model_tests.md)
- [x] [TEST_FEATURE_017 – `AnswerController` unit tests](./TEST_FEATURE_017_answer_controller_unit_tests.md)
- [x] [TEST_FEATURE_018 – `PlayerWidgetController` unit tests](./TEST_FEATURE_018_player_widget_controller_unit_tests.md)
- [x] [TEST_FEATURE_019 – `OM constants` unit tests](./TEST_FEATURE_019_om_constants_unit_tests.md)
- [x] [TEST_FEATURE_020 – `color_contrast` utilities unit tests](./TEST_FEATURE_020_color_contrast_unit_tests.md)
- [x] [TEST_FEATURE_021 – `colormap` score-to-color unit tests](./TEST_FEATURE_021_colormap_unit_tests.md)

---

### 2. Widget Tests – Screens

- [x] [TEST_FEATURE_030 – `MainScreen` widget tests](./TEST_FEATURE_030_main_screen_widget_tests.md)
- [x] [TEST_FEATURE_031 – `LobbyScreen` widget tests (including lobby ring colors)](./TEST_FEATURE_031_lobby_screen_widget_tests.md)
- [x] [TEST_FEATURE_032A – `QuestionScreenV2` rendering tests](./TEST_FEATURE_032_question_screen_v2_widget_tests.md#032a-rendering)
- [x] [TEST_FEATURE_032B – `QuestionScreenV2` carousel navigation tests](./TEST_FEATURE_032_question_screen_v2_widget_tests.md#032b-carousel-navigation)
- [x] [TEST_FEATURE_032C – `QuestionScreenV2` answer input & submit button tests](./TEST_FEATURE_032_question_screen_v2_widget_tests.md#032c-answer-input--submit-button)
- [x] [TEST_FEATURE_032D – `QuestionScreenV2` timer tests (deadline & auto-next)](./TEST_FEATURE_032_question_screen_v2_widget_tests.md#032d-timers)
- [x] [TEST_FEATURE_032E – `QuestionScreenV2` player updates & confetti tests](./TEST_FEATURE_032_question_screen_v2_widget_tests.md#032e-player-updates--confetti)
- [x] [TEST_FEATURE_032F – `QuestionScreenV2` review mode tests](./TEST_FEATURE_032_question_screen_v2_widget_tests.md#032f-review-mode)

---

### 3. Widget Tests – Core Widgets & Components

- [x] [TEST_FEATURE_040A – `AnswerWidget` rendering tests](./TEST_FEATURE_040_answer_widget_widget_tests.md#040a-rendering)
- [x] [TEST_FEATURE_040B – `AnswerWidget` input interaction tests](./TEST_FEATURE_040_answer_widget_widget_tests.md#040b-input-interaction)
- [x] [TEST_FEATURE_040C – `AnswerWidget` controller binding tests](./TEST_FEATURE_040_answer_widget_widget_tests.md#040c-controller-binding)
- [x] [TEST_FEATURE_040D – `AnswerWidget` reveal behavior tests](./TEST_FEATURE_040_answer_widget_widget_tests.md#040d-reveal-behavior)
- [x] [TEST_FEATURE_040E – `AnswerWidget` unit handling tests](./TEST_FEATURE_040_answer_widget_widget_tests.md#040e-unit-handling)
- [x] [TEST_FEATURE_040F – `AnswerWidget` bottom sheets tests](./TEST_FEATURE_040_answer_widget_widget_tests.md#040f-bottom-sheets)
- [x] [TEST_FEATURE_041 – `PlayerWidget` widget tests (including self/host ring colors)](./TEST_FEATURE_041_player_widget_widget_tests.md)
- [x] [TEST_FEATURE_042 – `QuestionWidget` widget tests](./TEST_FEATURE_042_question_widget_widget_tests.md)
- [x] [TEST_FEATURE_043 – `GameCard` widget tests](./TEST_FEATURE_043_game_card_widget_tests.md)
- [x] [TEST_FEATURE_044 – `PlayersRow` widget tests](./TEST_FEATURE_044_players_row_widget_tests.md)
- [x] [TEST_FEATURE_045 – `SubmitBar` widget tests](./TEST_FEATURE_045_submit_bar_widget_tests.md)
- [x] [TEST_FEATURE_046 – `QuickAccessBar` widget tests](./TEST_FEATURE_046_quick_access_bar_widget_tests.md)
- [x] [TEST_FEATURE_047 – `GameCarousel` widget tests](./TEST_FEATURE_047_game_carousel_widget_tests.md)

---

### 4. Integration Tests – User Flows

- [ ] [TEST_FEATURE_060 – `Full Game Flow` integration tests](./TEST_FEATURE_060_full_game_flow_integration_tests.md)
- [ ] [TEST_FEATURE_061 – `Auth Flow` integration tests](./TEST_FEATURE_061_auth_flow_integration_tests.md)
- [ ] [TEST_FEATURE_062 – `Real-time Synchronization` integration tests](./TEST_FEATURE_062_realtime_sync_integration_tests.md)
- [ ] [TEST_FEATURE_063 – `Answer Submission Flow` integration tests](./TEST_FEATURE_063_answer_submission_integration_tests.md)
- [ ] [TEST_FEATURE_064 – `Review Mode Flow` integration tests](./TEST_FEATURE_064_review_mode_integration_tests.md)
- [ ] [TEST_FEATURE_065 – `Voting Flow` integration tests](./TEST_FEATURE_065_voting_flow_integration_tests.md)
- [ ] [TEST_FEATURE_066 – `Locale Flow` integration tests](./TEST_FEATURE_066_locale_flow_integration_tests.md)
- [ ] [TEST_FEATURE_067 – `Error Handling` integration tests](./TEST_FEATURE_067_error_handling_integration_tests.md)

---

### Collaboration & Continuity Guidelines

- **Picking work**:
  - Prefer the **lowest-numbered unchecked feature** unless the roadmap or user says otherwise.
  - For integration tests, ensure foundational and relevant unit/widget tests are already in good shape.

- **Context to load for each feature** (smart context engineering):
  - This roadmap entry and the linked feature request markdown.
  - `docs/TESTING_GUIDELINES.md` (always).
  - `docs/TESTS.md` (for the precise test list).
  - `docs/TEST_FIXTURES.md` (to reuse fixtures and avoid duplication).
  - The specific `lib/` files mentioned in the feature request.

- **Continuity notes**:
  - Each feature request file has a **“Continuity notes”** section.
  - When you finish, briefly record:
    - Anything you intentionally deferred.
    - New fixtures/helpers you added.
    - Non-obvious design decisions.

- **Bug fixes vs tests**:
  - If a feature request references a **known issue**, you MUST:
    - Fix the bug in production code first.
    - Then write tests that assert the expected behavior.
  - Ensure the final tests reflect the intended production behavior, not the old buggy behavior.

- **Updating this roadmap**:
  - After implementing a feature request:
    - **Check off** the corresponding item above.
    - If you introduce a new test area that does not fit existing items, coordinate with the user before adding new roadmap entries.
