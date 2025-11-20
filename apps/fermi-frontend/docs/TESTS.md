# Flutter Frontend Test Plan

This document defines the comprehensive test suite for The Fermi Game Flutter frontend. Tests are organized following the Flutter Testing Pyramid: many unit tests, fewer widget tests, and few integration tests.

## **Table of Contents**

- [Test Organization](#test-organization)
- [Unit Tests](#unit-tests)
- [Widget Tests](#widget-tests)
- [Integration Tests](#integration-tests)
- [Test Data and Fixtures](#test-data-and-fixtures)
- [Test Execution](#test-execution)

---

## **Test Organization**

### Directory Structure

```
apps/fermi-frontend/
├── test/
│   ├── unit/
│   │   ├── controllers/
│   │   ├── services/
│   │   ├── models/
│   │   └── utils/
│   ├── widget/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── components/
│   ├── integration/
│   │   ├── flows/
│   │   └── scenarios/
│   ├── fixtures/
│   │   ├── game_snapshots.dart
│   │   ├── question_data.dart
│   │   └── player_data.dart
│   └── helpers/
│       ├── mock_factories.dart
│       ├── test_helpers.dart
│       └── firebase_emulator_setup.dart
```

### Test Naming Convention

- **Unit tests**: `{component}_test.dart` (e.g., `main_screen_controller_test.dart`)
- **Widget tests**: `{widget}_test.dart` (e.g., `answer_widget_test.dart`)
- **Integration tests**: `{flow}_test.dart` (e.g., `full_game_flow_test.dart`)

---

## **Unit Tests**

Unit tests verify business logic in isolation with mocked dependencies. They must be fast (<100ms each) and have zero external dependencies.

### *Controllers*

#### `MainScreenController` (`test/unit/controllers/main_screen_controller_test.dart`)

**Test Groups:**

1. **Initialization**
   - `should initialize with loading state`
   - `should load game config on initialize`
   - `should load player stats on initialize when user is authenticated`
   - `should restore last round settings on initialize`
   - `should handle initialization errors gracefully`
   - `should set isLoading to false after initialization`

2. **Category Selection**
   - `should select category by index`
   - `should deselect category when index is null`
   - `should compute currentCategoryBackendName correctly`
   - `should compute currentCategorySlug correctly`
   - `should return null when no category selected`
   - `should clamp category index to valid range`

3. **Difficulty Selection**
   - `should select difficulty`
   - `should deselect difficulty when null`
   - `should notify listeners on difficulty change`

4. **Privacy Toggle**
   - `should toggle lock state`
   - `should notify listeners on toggle`

5. **Percentile Calculation**
   - `should return 0 when no stats available`
   - `should return overall percentile when no category/difficulty selected`
   - `should return difficulty percentile when only difficulty selected`
   - `should return category percentile when only category selected`
   - `should return category+difficulty percentile when both selected`
   - `should clamp percentile to 0-100 range`
   - `should handle missing stats gracefully`

6. **Game Creation**
   - `should create private game with selected settings`
   - `should create public game with selected settings`
   - `should persist last round settings after creation`
   - `should set isSubmitting during creation`
   - `should handle creation errors`
   - `should clear error message on success`

7. **Join Random Game**
   - `should join random game with selected settings`
   - `should persist last round settings after join`
   - `should set isSubmitting during join`
   - `should handle join errors`
   - `should clear error message on success`

8. **Realtime Adapter Factory**
   - `should build FirestoreGameRealtime with correct parameters`
   - `should pass current player ID to adapter`
   - `should wire API methods correctly`

#### `LobbyScreenController` (`test/unit/controllers/lobby_screen_controller_test.dart`)

**Note:** `LobbyScreenController` is a `StatefulWidget`, not a pure controller. These tests focus on the state management logic extracted into testable methods.

**Test Groups:**

1. **State Management**
   - `should initialize with initial players`
   - `should update players from game snapshot`
   - `should detect host status from snapshot`
   - `should detect lobby ready state`
   - `should detect private game state`
   - `should extract join URL from snapshot`

2. **Navigation Logic**
   - `should navigate to question screen when state becomes QUESTION_N`
   - `should navigate to question screen when state becomes QUESTION_LAST`
   - `should not navigate twice for same transition`
   - `should pass correct question count to question screen`

3. **Game Actions**
   - `should start game when host and lobby ready`
   - `should not start game when not host`
   - `should not start game when lobby not ready`
   - `should handle start game errors`
   - `should share invite URL for private games`
   - `should show error when share URL is missing`
   - `should handle share errors`

4. **Leave Game**
   - `should call leave game API`
   - `should navigate to main screen after leave`
   - `should handle leave errors`

#### `QuestionScreenV2Controller` (organized in folders: `test/unit/controllers/question_screen_v2_controller_012A/` and `test/unit/controllers/question_screen_v2_controller_012B/`)

**Test Groups:**

1. **Initialization**
   - `should initialize with default state`
   - `should attach to game stream on attach`
   - `should initialize answer controller on attach`
   - `should initialize deadline tracker on attach`
   - `should set current locale from realtime`

2. **Question State Caching**
   - `should cache question state when revealed`
   - `should update cached question state`
   - `should return null for uncached question`
   - `should preserve cached state across index changes`

3. **Index Management**
   - `should update current index from backend in live mode`
   - `should not update index from backend in review mode`
   - `should call carousel controller to animate on index change`
   - `should stop deadline timer when changing questions`
   - `should initialize answer for new question`

4. **Answer Input**
   - `should update current answer on change`
   - `should convert UI answer to submission format`
   - `should handle unit abbreviation to ID mapping`
   - `should submit unitless answer as null`
   - `should prevent duplicate submissions`
   - `should not submit in review mode`

5. **Answer Submission**
   - `should submit answer via realtime`
   - `should set local submitted answer`
   - `should handle submission errors`
   - `should wait for unit maps before submission`
   - `should apply fallbacks for deadline auto-submit`

6. **Deadline Timer**
   - `should start timer when question becomes active`
   - `should stop timer when question revealed`
   - `should stop timer when manually submitted`
   - `should auto-submit on deadline expiration`
   - `should not start timer in review mode`
   - `should not start timer if duration is zero`

7. **Auto-Next Timer**
   - `should start auto-next timer after reveal`
   - `should not start timer for last question`
   - `should not start timer in review mode`
   - `should cancel timer when host manually advances`
   - `should cancel timer when question changes`
   - `should auto-advance when timer expires (host only)`
   - `should update progress every 100ms`

8. **Reveal Handling**
   - `should update question state on reveal`
   - `should call reveal on AnswerController`
   - `should calculate reveal color from score`
   - `should convert correct answer to display format`
   - `should handle reveal for non-current questions`

9. **Players Answers Handling**
   - `should calculate cumulative scores correctly`
   - `should update player controllers with scores`
   - `should call triggerConfetti on the correct PlayerWidgetController`
   - `should not trigger confetti in review mode`
   - `should update player states with submitted answers`
   - `should calculate percentiles correctly`

10. **Review Mode**
    - `should enter review mode when game finished`
    - `should allow carousel navigation in review mode`
    - `should update players for review index`
    - `should replay cached scores in review mode`
    - `should not allow answer submission in review mode`
    - `should not start timers in review mode`

11. **Voting**
    - `should upvote question`
    - `should de-upvote question`
    - `should downvote question`
    - `should de-downvote question`
    - `should update vote state in question state`
    - `should update upvote count correctly`

12. **Locale Management**
    - `should update locale via realtime`
    - `should notify listeners on locale change`
    - `should update unit options notifier`

13. **Confetti Management**
    - `should set confetti rank for top 3 players`
    - `should calculate final ranks correctly`
    - `should persist confetti across carousel navigation`
    - `should clear confetti when requested`

14. **Player Controllers**
    - `should create player controllers for new players`
    - `should dispose controllers for removed players`
    - `should update player controller scores`
    - `should replay scores on controller bind`

15. **Disposal**
    - `should cancel game stream subscription`
    - `should cancel auto-next timer`
    - `should dispose deadline tracker`
    - `should dispose all bindings`
    - `should dispose all player controllers`
    - `should dispose unit options notifier`

### *Services*

#### `ApiService` (`test/unit/services/api_service_test.dart`)

**Test Groups:**

1. **Authentication**
   - `should include access token in requests`
   - `should refresh token on 401 response`
   - `should retry request after token refresh`
   - `should throw exception when unauthorized`
   - `should throw exception when refresh fails`

2. **Game Config**
   - `should fetch game config successfully`
   - `should parse game config JSON correctly`
   - `should handle network errors`
   - `should handle server errors`

3. **Player Stats**
   - `should fetch player stats successfully`
   - `should parse player stats JSON correctly`
   - `should handle network errors`
   - `should handle server errors`

4. **Game Creation**
   - `should create private game with correct body`
   - `should create public game with correct body`
   - `should include category and difficulty in body`
   - `should include nQuestions in body`
   - `should return game ID from response`
   - `should handle creation errors`

5. **Join Random Game**
   - `should join random game with correct body`
   - `should include category and difficulty in body`
   - `should return game ID from response`
   - `should handle join errors`

6. **Start Game**
   - `should start game with correct game ID`
   - `should handle start errors`

7. **Answer Submission**
   - `should apply OM multiplier correctly`
   - `should send unit ID in submission`
   - `should send null for unitless answers`
   - `should handle submission errors`
   - `should clamp number to 1-999 range`

8. **Next Question**
   - `should request next question with correct game ID`
   - `should handle next question errors`

9. **Remove Player**
   - `should remove player with correct IDs`
   - `should handle remove errors`

10. **Question Voting**
    - `should upvote question`
    - `should de-upvote question (via downvote toggle)`
    - `should downvote question`
    - `should de-downvote question (via upvote toggle)`
    - `should handle voting errors`

11. **User Locale**
    - `should set user locale`
    - `should update auth service locale`
    - `should handle locale errors`

12. **Error Handling**
    - `should extract error message from JSON detail`
    - `should handle non-JSON error responses`
    - `should handle empty error responses`
    - `should trim long error messages`

#### `AuthService` (`test/unit/services/auth_service_test.dart`)

**Test Groups:**

1. **Token Exchange**
   - `should exchange Firebase token for access token`
   - `should store access token`
   - `should parse user object from response`
   - `should store firebase UID`
   - `should store locale from user object`
   - `should return false on exchange failure`
   - `should handle network errors`
   - `should handle invalid token`

2. **Token Refresh**
   - `should refresh access token successfully`
   - `should update access token`
   - `should update user object`
   - `should fallback to exchange on 401`
   - `should return false on refresh failure`
   - `should handle network errors`

3. **State Management**
   - `should store last round settings`
   - `should clear last round settings`
   - `should track shouldRefreshStats flag`

#### `GameRealtime` Interface (`test/unit/services/game_realtime_test.dart`)

**Test Groups:**

1. **FirestoreGameRealtime Implementation**
   - `should map game document to GameSnapshot`
   - `should parse game state enum correctly`
   - `should extract player summaries`
   - `should detect host status`
   - `should calculate question number from UID`
   - `should extract duration from game doc`
   - `should extract progress answered map`
   - `should filter revealed questions`
   - `should filter revealed answers`
   - `should filter revealed players results`
   - `should map units by locale`
   - `should build unit abbreviation to ID maps`
   - `should handle missing game document`
   - `should handle missing subcollections`

2. **Stream Behavior**
   - `should emit snapshots on document changes`
   - `should emit question on reveal`
   - `should emit answers when all players answered`
   - `should emit reveal payload when revealed`
   - `should handle stream errors`

3. **Command Execution**
   - `should call submit function on submitAnswer`
   - `should call next function on goNext`
   - `should call vote functions correctly`
   - `should call locale functions correctly`

### *Models*

#### `AnswerValue` (`test/unit/models/answer_value_test.dart`)

**Test Groups:**

1. **Equality**
   - `should be equal when all fields match`
   - `should not be equal when number differs`
   - `should not be equal when OM differs`
   - `should not be equal when unit differs`

2. **Hash Code**
   - `should produce same hash for equal values`
   - `should produce different hash for different values`

3. **String Representation**
   - `should format toString correctly`

### *Widget Controllers*

#### `AnswerController` (`test/unit/widgets/answer_controller_test.dart`)

**Test Groups:**

1. **Binding**
   - `should bind sub-controllers`
   - `should expose current value getter`
   - `should expose reveal function`
   - `should expose reset function`

2. **Value Operations**
   - `should jump to value instantly`
   - `should animate to value`
   - `should reveal with color`
   - `should reset visual state`
   - `should close bottom sheets`
   - `should request focus`

3. **Default Values**
   - `should return default value when not bound`
   - `should handle operations when not bound gracefully`

#### `PlayerWidgetController` (`test/unit/widgets/player_widget_controller_test.dart`)

**Test Groups:**

1. **Binding**
   - `should bind callbacks`
   - `should replay last round score on bind`
   - `should replay last score on bind`

2. **Score Updates**
   - `should set round score`
   - `should set cumulative score`
   - `should trigger confetti`
   - `should clear confetti`

3. **State Persistence**
   - `should remember last round score`
   - `should remember last score`
   - `should clear state on dispose`

### *Utilities*

#### `OM Constants` (`test/unit/utils/om_constants_test.dart`)

**Test Groups:**

1. **Multiplier Lookup**
   - `should return correct multiplier for each OM`
   - `should return 1 for empty OM`
   - `should return 1 for unknown OM`

#### `Color Utilities` (`test/unit/utils/color_contrast_test.dart`)

**Test Groups:**

1. **Contrast Calculation**
   - `should calculate contrast ratio correctly`
   - `should return white for dark backgrounds`
   - `should return black for light backgrounds`
   - `should handle edge cases`

#### `Score to Color` (`test/unit/utils/colormap_test.dart`)

**Test Groups:**

1. **Color Mapping**
   - `should map low scores to danger color`
   - `should map high scores to success color`
   - `should interpolate between colors`
   - `should handle edge scores`

---

## **Widget Tests**

Widget tests verify UI components in isolation with mocked dependencies. They test widget rendering, user interactions, and state changes.

### *Screens*

#### `MainScreen` (`test/widget/screens/main_screen_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display loading indicator when initializing`
   - `should display error message on initialization error`
   - `should display category carousel when loaded`
   - `should display difficulty selector when loaded`
   - `should display privacy toggle when loaded`
   - `should display percentile panel when stats loaded`
   - `should display create game button`
   - `should display join random button`

2. **Category Selection**
   - `should highlight selected category`
   - `should call controller on category tap`
   - `should update percentile when category changes`

3. **Difficulty Selection**
   - `should highlight selected difficulty`
   - `should call controller on difficulty tap`
   - `should update percentile when difficulty changes`

4. **Privacy Toggle**
   - `should show private state when locked`
   - `should show public state when unlocked`
   - `should call controller on toggle`

5. **Game Actions**
   - `should navigate to lobby on create game`
   - `should navigate to lobby on join random`
   - `should show error snackbar on create failure`
   - `should show error snackbar on join failure`
   - `should disable buttons while submitting`

6. **Navigation**
   - `should navigate to profile screen`
   - `should handle back navigation`

#### `LobbyScreen` (`test/widget/screens/lobby_screen_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display player list`
   - `should display waiting spinner for public games`
   - `should display start button for host when ready`
   - `should disable start button when not ready`
   - `should display share button for private games`
   - `should display leave button`

2. **Player Display**
   - `should show player avatars`
   - `should show player names`
   - `should highlight host`
   - `should highlight current player`

3. **Actions**
   - `should call onStart when start button tapped`
   - `should call onShare when share button tapped`
   - `should show error when share URL missing`
   - `should call onLeave when leave button tapped`
   - `should show confirm dialog before leaving`

4. **State Updates**
   - `should update when players join`
   - `should update when players leave`
   - `should enable start when lobby ready`
   - `should navigate to question screen automatically`

#### `QuestionScreenV2` (`test/widget/screens/question_screen_v2_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display players row`
   - `should display game carousel`
   - `should display quick access bar`
   - `should display submit button`
   - `should display leave button`

2. **Carousel Navigation**
   - `should display correct question in carousel`
   - `should show dots indicator`
   - `should update dots on page change`
   - `should animate carousel when controller's index changes`
   - `should animate carousel on programmatic navigation`
   - `should allow swipe navigation in review mode`
   - `should prevent swipe navigation in live mode`

3. **Answer Input**
   - `should display answer widget`
   - `should update answer on input`
   - `should show reveal animation in AnswerWidget when question is revealed`
   - `should disable input when revealed`
   - `should show revealed answer after reveal`

4. **Submit Button**
   - `should show submit text when editable`
   - `should show next text when revealed (host)`
   - `should show finish text on last question (host)`
   - `should disable button when not host in review`
   - `should call submit on tap`
   - `should call next on tap (host)`

5. **Deadline Timer**
   - `should display progress indicator`
   - `should update progress over time`
   - `should show color gradient (blue to red)`
   - `should stop when revealed`

6. **Auto-Next Timer**
   - `should display circular progress after reveal`
   - `should update progress over time`
   - `should auto-advance when expires (host)`
   - `should cancel when host manually advances`

7. **Player Updates**
   - `should update player scores`
   - `should show submitted answers after reveal`
   - `should animate score changes`
   - `should show rank badges for top 3`

8. **Confetti**
   - `should show confetti for top 3 at game end`
   - `should show confetti for highest scorer per question`
   - `should persist confetti in review mode`

9. **Review Mode**
   - `should allow carousel navigation`
   - `should show cached question states`
   - `should disable answer input`
   - `should show finish button`

### *Widgets*

#### `AnswerWidget` (`test/widget/widgets/answer_widget_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display digit wheels`
   - `should display OM label`
   - `should display unit tape`
   - `should hide unit tape when no units`
   - `should show initial value`

2. **Input Interaction**
   - `should update number on digit input`
   - `should update OM on selection`
   - `should update unit on selection`
   - `should call onChanged on any change`
   - `should open numpad on digit tap`
   - `should open OM selector on tap`
   - `should open unit selector on tap`

3. **Controller Binding**
   - `should bind to controller`
   - `should jump to value when controller calls jumpTo`
   - `should animate to value when controller calls animateTo`
   - `should reveal when controller calls reveal`
   - `should reset visual state when controller calls reset`

4. **Reveal Behavior**
   - `should animate digits to correct value`
   - `should animate OM to correct value`
   - `should animate unit to correct value`
   - `should change text color to reveal color`
   - `should fade out tap indicators`
   - `should disable input after reveal`

5. **Unit Handling**
   - `should display unit abbreviations`
   - `should show full names in selector`
   - `should update units on locale change`
   - `should handle unitless questions`

6. **Bottom Sheets**
   - `should close OM selector on selection`
   - `should close unit selector on selection`
   - `should close on outside tap`
   - `should close on drag down`

#### `PlayerWidget` (`test/widget/widgets/player_widget_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display player avatar`
   - `should display player name`
   - `should display score`
   - `should display rank badge for top 3`
   - `should highlight host`
   - `should highlight current player`

2. **Status Display**
   - `should show waiting status before answer`
   - `should show ready status after answer`
   - `should show answer chip after reveal`
   - `should color answer chip by score`

3. **Ring Progress**
   - `should display countdown ring during question`
   - `should complete ring on submission`
   - `should show static ring in review mode`
   - `should use correct colors (self vs others)`
   - `should handle host color correctly`

4. **Ring Progress (Multi-Player Scenarios)**
   - **Self View**
     - `should show decrementing ring before self submits`
     - `should show completed success-colored ring after self submits`
     - `should not be affected by other players submitting`
   - **Opponent View**
     - `should show other players' decrementing rings before they submit`
     - `should show other players' completed rings after they submit`
     - `should not be affected by self submitting`

5. **Score Animation**
   - `should animate score increase`
   - `should show round score chip on reveal`
   - `should clear round score chip on next question`
   - `should animate cumulative score`

6. **Confetti**
   - `should trigger confetti for highest scorer`
   - `should clip confetti to widget bounds`
   - `should clear confetti on next question`

7. **Controller Binding**
   - `should bind to PlayerWidgetController`
   - `should update on controller score changes`
   - `should trigger confetti on controller call`

#### `QuestionWidget` (`test/widget/widgets/question_widget_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display question text`
   - `should display tags`
   - `should display like/dislike widget`
   - `should show upvote count`

2. **Voting**
   - `should call onUpvote on upvote tap`
   - `should call onDownvote on downvote tap`
   - `should update vote state`
   - `should animate vote button`
   - `should update upvote count`

3. **Copy Feature**
   - `should copy question text on long press`
   - `should copy question text on copy icon tap`
   - `should show feedback on copy`

#### `GameCard` (`test/widget/widgets/game_card_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display question widget`
   - `should display answer widget`
   - `should display feedback row after reveal`
   - `should animate height when feedback appears`

2. **State Management**
   - `should show editable answer before reveal`
   - `should show revealed answer after reveal`
   - `should show percentile when >= 50%`
   - `should hide percentile when < 50%`

#### `PlayersRow` (`test/widget/widgets/players_row_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display all players`
   - `should sort players by rank`
   - `should center align players`
   - `should handle empty player list`

2. **Player Updates**
   - `should update when players change`
   - `should reorder when ranks change`
   - `should remove players who left`

#### `SubmitBar` (`test/widget/widgets/submit_bar_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should show submit text when editable`
   - `should show next text when revealed (host)`
   - `should show finish text on last question (host)`
   - `should disable button when not host`

2. **Progress Indicators**
   - `should show deadline progress`
   - `should show auto-next progress after reveal`
   - `should update progress over time`

3. **Actions**
   - `should call onSubmit on tap`
   - `should call onNext on tap (host)`
   - `should call onFinish on tap (host)`

#### `QuickAccessBar` (`test/widget/widgets/quick_access_bar_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display drag indicator`
   - `should display progress indicator`
   - `should display "Show numpad" text`

2. **Drag Interaction**
   - `should open numpad on drag up (80px threshold)`
   - `should close bottom sheets on drag down`
   - `should update progress during drag`

#### `GameCarousel` (`test/widget/widgets/game_carousel_test.dart`)

**Test Groups:**

1. **Rendering**
   - `should display carousel with questions`
   - `should display dots indicator`
   - `should show correct question at index`

2. **Navigation**
   - `should update dots on page change`
   - `should call onPageChanged on swipe`
   - `should animate on programmatic navigation`
   - `should prevent navigation in live mode (non-review)`

---

## **Integration Tests**

Integration tests verify complete user flows with real Firebase emulators. They test end-to-end scenarios and real-time synchronization.

### *Test Setup*

All integration tests must:
1. Initialize Firebase emulators (Auth + Firestore)
2. Configure app to use emulators
3. Set up test users
4. Clean up after each test

See `test/helpers/firebase_emulator_setup.dart` for setup utilities.

### *Flows*

#### `Full Game Flow` (`test/integration/flows/full_game_flow_test.dart`)

**Test Groups:**

1. **Happy Path: Single Player**
   - `should complete full game from create to finish`
   - `should create private game`
   - `should navigate to lobby`
   - `should start game`
   - `should navigate to question screen`
   - `should display first question`
   - `should submit answer`
   - `should reveal answer after all answered`
   - `should advance to next question`
   - `should complete all questions`
   - `should enter review mode`
   - `should navigate back to main screen on finish`

2. **Happy Path: Multi-Player**
   - `should complete game with multiple players`
   - `should show all players in lobby`
   - `should update players list when players join`
   - `should show all players in question screen`
   - `should show other players' answers after reveal`
   - `should calculate scores correctly`
   - `should show rankings correctly`

3. **Public Game Flow**
   - `should join random public game`
   - `should show waiting spinner in lobby`
   - `should start automatically when host starts`

4. **Private Game Flow**
   - `should create private game`
   - `should generate join URL`
   - `should share join URL`
   - `should allow players to join via URL`

### *Scenarios*

#### `Authentication Flow` (`test/integration/scenarios/auth_flow_test.dart`)

**Test Groups:**

1. **Sign In**
   - `should sign in with email`
   - `should exchange token after sign in`
   - `should navigate to main screen after sign in`
   - `should show error on sign in failure`
   - `should show error on token exchange failure`

2. **Token Refresh**
   - `should refresh token on 401`
   - `should retry request after refresh`
   - `should sign out on refresh failure`

3. **Sign Out**
   - `should sign out successfully`
   - `should navigate to sign in screen`
   - `should clear access token`

#### `Real-time Synchronization` (`test/integration/scenarios/realtime_sync_test.dart`)

**Test Groups:**

1. **Game State Updates**
   - `should update UI when game state changes`
   - `should update players list in real-time`
   - `should update question when revealed`
   - `should update answers when revealed`
   - `should update scores in real-time`

2. **Multi-Player Synchronization**
   - `should show other players' submissions`
   - `should update when other players submit`
   - `should reveal when all players answered`
   - `should show scores for all players`

3. **Connection Handling**
   - `should handle connection loss gracefully`
   - `should reconnect automatically`
   - `should show error on persistent connection loss`

#### `Answer Submission Flow` (`test/integration/scenarios/answer_submission_test.dart`)

**Test Groups:**

1. **Manual Submission**
   - `should submit answer on button tap`
   - `should disable input after submission`
   - `should show submitted state`
   - `should handle submission errors`

2. **Auto-Submission**
   - `should auto-submit on deadline expiration`
   - `should submit current input value`
   - `should apply fallbacks for missing unit`
   - `should handle auto-submit errors`

3. **Answer Validation**
   - `should submit valid answers`
   - `should handle unitless questions`
   - `should convert unit abbreviation to ID`

#### `Review Mode Flow` (`test/integration/scenarios/review_mode_test.dart`)

**Test Groups:**

1. **Navigation & Activation**
   - `should enter review mode when game state is QUESTION_LAST_FINISHED`
   - `should not be active during live gameplay states`
   - `should display all questions and allow navigation to any index`
   - `should remain in review mode until user explicitly leaves`

2. **Carousel Navigation**
   - `should swipe forward and backward through all questions`
   - `should not crash or corrupt data on rapid swipes`
   - `should update dots indicator correctly during swipe`
   - `should prevent swiping beyond first or last question`

3. **Player Reordering & Display**
   - `should reorder players based on cumulative score at each question index`
   - `should animate player reordering smoothly`
   - `should maintain stable order for players with identical scores (tiebreaker)`

4. **Rank Icons (Medals)**
   - `should display gold, silver, bronze medals for top 3 players`
   - `should ensure rank icons follow players as they reorder`
   - `should update icons correctly when players enter/exit top 3`

5. **Score Updates & Animations**
   - `should display correct cumulative scores for each question index`
   - `should animate cumulative score changes between questions`
   - `should display correct per-question round scores in answer chips`

6. **Answer Display**
   - `should show correct answers on all question cards`
   - `should show player's submitted answer in their answer chip`
   - `should color both answer widget and answer chip based on score`

7. **Percentile & Feedback Display**
   - `should show percentile text when score is >= 50% and hide it otherwise`
   - `should update percentile text when navigating between questions`
   - `should preserve vote state (like/dislike) when navigating`

8. **Button States & Actions**
   - `should disable Submit/Next buttons`
   - `should show a functional Finish button that navigates to Main Screen`
   - `should show a functional Leave button with confirmation dialog`

9. **Confetti & Celebrations**
   - `should show game-end confetti for top 3 players upon entering review mode`
   - `should persist game-end confetti across carousel navigation`
   - `should NOT show per-question confetti`

10. **Edge Cases**
    - `should handle games with only 1 question`
    - `should handle games with 1 player`
    - `should handle players who did not submit an answer`
    - `should handle rapid back-and-forth scrolling without crashes`

#### `Voting Flow` (`test/integration/scenarios/voting_flow_test.dart`)

**Test Groups:**

1. **Upvote**
   - `should upvote question`
   - `should update upvote count`
   - `should update vote state`
   - `should persist vote state`

2. **Downvote**
   - `should downvote question`
   - `should update vote state`
   - `should persist vote state`

3. **Toggle Votes**
   - `should remove upvote on de-upvote`
   - `should remove downvote on de-downvote`
   - `should toggle between upvote and downvote`

#### `Locale Flow` (`test/integration/scenarios/locale_flow_test.dart`)

**Test Groups:**

1. **Locale Selection**
   - `should switch between US and EU units`
   - `should update unit options`
   - `should persist locale preference`
   - `should update answer widget units`

2. **Unit Display**
   - `should show US units when US selected`
   - `should show EU units when EU selected`
   - `should update unit abbreviations`

#### `Error Handling` (`test/integration/scenarios/error_handling_test.dart`)

**Test Groups:**

1. **Network Errors**
   - `should show error on API failure`
   - `should retry on transient errors`
   - `should handle timeout errors`

2. **Firestore Errors**
   - `should handle missing game document`
   - `should handle missing question documents`
   - `should handle permission errors`

3. **State Errors**
   - `should handle invalid game state`
   - `should handle missing question UIDs`
   - `should handle missing player data`

---

## **Test Data and Fixtures**

### *Fixtures* (`test/fixtures/`)

#### `game_snapshots.dart`
- Factory functions for `GameSnapshot` objects
- Different game states (lobby, question, finished)
- Multi-player scenarios

#### `question_data.dart`
- Sample question text, tags, units
- Correct answers
- Unit mappings

#### `player_data.dart`
- Sample player states
- Player summaries
- Score data

### *Mock Factories* (`test/helpers/mock_factories.dart`)

- `MockApiService`: Mock API service with configurable responses
- `MockAuthService`: Mock auth service with configurable state
- `MockGameRealtime`: Mock realtime adapter with configurable streams
- `MockFirestoreGameRealtime`: Mock Firestore adapter

---

## **Test Execution**

### *Running Tests*

**Recommended: Use the Makefile target** (includes all required dart-defines):

```bash
# Run all frontend unit tests with proper configuration
make test-frontend-unit
```

**Note**: When new `--dart-define` flags are needed for tests, update both:
1. The `test-frontend-unit` target in the root `Makefile`
2. This documentation section

**Manual execution** (for reference or when Makefile is unavailable):

```bash
# Run all tests
fvm flutter test

# Run unit tests only (requires API_BASE_URL dart-define)
fvm flutter test test/unit/ --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPPRESS_TEST_LOGS=true

# Run widget tests only (with suppressed logs for cleaner output)
fvm flutter test test/widget/ --dart-define=SUPPRESS_TEST_LOGS=true

# Run integration tests (requires emulators and dart-defines)
fvm flutter test test/integration/

# Run specific test file (requires API_BASE_URL dart-define)
fvm flutter test test/unit/controllers/main_screen_controller_test.dart \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPPRESS_TEST_LOGS=true

# Run with coverage (with suppressed logs)
fvm flutter test --coverage \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=SUPPRESS_TEST_LOGS=true
```

**Note**: The `SUPPRESS_TEST_LOGS` flag suppresses debug/info/warning logs during test execution for cleaner output. Errors are always logged regardless of this flag.

### *Prerequisites for Integration Tests*

1. Start Firebase emulators:
   ```bash
   make up  # Starts db and emulators
   ```

2. Ensure emulators are accessible:
   - Firestore: `127.0.0.1:8080`
   - Auth: `127.0.0.1:9099`

3. Run integration tests:
   ```bash
   fvm flutter test test/integration/ --dart-define=USE_EMULATORS=true \
     --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
     --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
   ```

### *CI/CD Integration*

Integration tests should run in CI with:
- Firebase emulators started in background
- Proper environment variables set
- Test isolation (clean state between tests)
- Coverage reporting

---

## **Test Coverage Goals**

- **Unit Tests**: 80%+ coverage for controllers, services, and models
- **Widget Tests**: 70%+ coverage for critical widgets and screens
- **Integration Tests**: Cover all major user flows

---

## **Notes for LLM Agents**

When implementing tests:

1. **Follow AAA Pattern**: Arrange, Act, Assert
2. **Use Keys**: Always use `ValueKey` for finding widgets
3. **Mock Dependencies**: Use `mocktail` for all external dependencies
4. **Test One Thing**: Each test should verify one behavior
5. **Use Descriptive Names**: Test names should clearly describe what they test
6. **Group Related Tests**: Use `group()` to organize related tests
7. **Clean Up**: Dispose controllers, cancel streams, reset mocks
8. **Test Edge Cases**: Include boundary conditions and error cases
9. **Verify Notifications**: Test that `notifyListeners()` is called appropriately
10. **Test Animations**: Use `pumpAndSettle()` to wait for animations

For integration tests:
- Use real Firebase emulators (not mocks)
- Clean up test data after each test
- Use polling with timeouts for eventual consistency
- Test both success and error paths
- Verify UI updates match backend state
