# Fermi Frontend Architecture

This document describes the architecture, design decisions, and implementation details of The Fermi Game's Flutter frontend application.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Authentication & API Integration](#authentication--api-integration)
- [Subscription Management](#subscription-management)
- [Real-time Game State](#real-time-game-state)
- [Screen Architecture](#screen-architecture)
  - [Main Screen](#main-screen)
  - [Lobby Screen](#lobby-screen)
  - [Question Screen](#question-screen)
- [Question Screen V2 Deep Dive](#question-screen-v2-deep-dive)
- [Question Screen V1 Deep Dive (Legacy)](#question-screen-v1-deep-dive-legacy---reference-only)
- [Answer Input System](#answer-input-system)
- [Theming System](#theming-system)
- [Visual Behaviors](#visual-behaviors)
- [Deep Links & Cross-Platform Invites](#deep-links--cross-platform-invites)
- [Development Guidelines](#development-guidelines)
- [Design Decisions](#design-decisions)

---

## Overview

The Fermi Game frontend is a Flutter application that provides an engaging trivia experience built around Fermi questions. The frontend's primary responsibility is to mirror backend state from Firestore with minimal client-side business logic.

### Core Principles

- **Source of truth**: The Firestore game document and its revealed subcollections (`questions`, `answers`, `players_results`). Clients listen to the game doc and to subcollection queries where `revealed == true`.
- **Initiate via API, propagate via Firestore**: Client actions call REST endpoints (e.g., `/game/start`, `/game/answer`, `/game/next_question`, `/game/end`). The backend updates Firestore; the UI reflects those updates in real time. The app does not write Firestore directly for gameplay state.
- **Minimal local state**: Controllers orchestrate view state (loading, timers, navigation) and derive all gameplay state from streams. Avoid duplicating or synthesizing server state on the client.
- **Deadlines and auto-submit**: A deadline timer enforces `question_duration_s`; when time elapses, the client auto-submits the current input via `/game/answer`.
- **Units**: Question `units` are a map with `US` and `EU`, each containing `UnitInfo` objects. The UI displays `US` options for now and shows the `abbreviation`; submissions send the unit `id` (or `null` for unitless).
- **Security and visibility**: Frontend reads revealed documents only and surfaces backend errors in SnackBars or dialogs; all writes go through authenticated API calls.

### Design Choices

- **Real-time, event-driven UI**: Views react to backend events via a `GameRealtime` adapter (`lib/services/game_realtime.dart`), enabling Firestore-backed prod adapters and a deterministic demo adapter (`lib/services/demo/demo_game_realtime.dart`).
- **Local, explicit state**: Screens/widgets use lightweight controllers (e.g., `QuestionPaneController`) and `ChangeNotifier` for orchestration; no global state manager required yet.
- **Unified theming**: The `AppTheme` `ThemeExtension` (`lib/theme/app_theme.dart`) provides consistent colors across the application (backgrounds, text, borders, semantic colors).
- **Responsive layout**: Shared sizing and spacing live in `LayoutConstants` (`lib/theme/layout_constants.dart`). Visual progress is decoupled from logical deadlines via `LinearDeterminateProgressIndicator` and `QuestionDeadlineTimer`.
- **Demo-first workflow**: `lib/main.dart` hosts focused demos for widgets and screens while keeping production code clean.

### Component Architecture

The frontend follows a component-based architecture with clear separation of concerns:

1. **Screens**: Top-level views that handle navigation and high-level state.
2. **Widgets**: Reusable UI components with encapsulated behavior.
3. **Services**: Backend adapters and utility services (auth, real-time, timers).
4. **Theme**: Centralized theming and layout constants.

---

## Project Structure

```
apps/fermi-frontend/
└── lib/
    ├── main.dart                     # App entry (auth routing → MainScreen)
    ├── widget_test_harness.dart      # Isolated widget demos (dev only)
    ├── models/                       # Data models and DTOs
    │   ├── answer_value.dart         # Complete answer (number, OM, unit)
    │   ├── reference.dart            # Question references
    │   ├── game_config.dart          # Game configuration
    │   └── player_stats.dart         # Player statistics
    ├── screens/
    │   ├── main/
    │   │   ├── main_screen.dart      # Main screen with tab navigation
    │   │   ├── main_screen_controller.dart
    │   │   └── widgets/
    │   │       ├── games_tab.dart            # Games tab content
    │   │       ├── me_tab.dart               # Me tab with user profile
    │   │       ├── party_bottom_sheet.dart   # Party game settings sheet
    │   │       ├── daily_question_carousel.dart
    │   │       ├── daily_question_card.dart
    │   │       ├── daily_question_archive_sheet.dart
    │   │       ├── primary_cta.dart
    │   │       └── top_bar_lock_avatar.dart
    │   ├── lobby/
    │   │   ├── lobby_screen.dart
    │   │   └── lobby_screen_controller.dart
    │   ├── daily_question/                   # Daily Question feature
    │   │   ├── daily_question_screen.dart
    │   │   └── daily_question_results_screen.dart
    │   ├── question_v2/                      # Question Screen V2 (current)
    │   │   ├── question_screen_v2.dart
    │   │   ├── question_screen_v2_controller.dart
    │   │   ├── controllers/                  # Manager classes
    │   │   │   ├── animation_state_manager.dart
    │   │   │   ├── answer_submission_handler.dart
    │   │   │   ├── confetti_manager.dart
    │   │   │   ├── game_timer_manager.dart
    │   │   │   ├── navigation_coordinator.dart
    │   │   │   ├── player_state_manager.dart
    │   │   │   └── question_state_manager.dart
    │   │   ├── models/
    │   │   │   ├── question_state.dart
    │   │   │   └── question_pane_state.dart
    │   │   └── widgets/
    │   │       ├── game_carousel.dart
    │   │       ├── game_card.dart
    │   │       └── quick_access_bar.dart
    │   └── question/                         # Legacy V1 (reference only)
    │       └── ...
    ├── services/
    │   ├── api_service.dart
    │   ├── auth_service.dart
    │   ├── daily_question_service.dart
    │   ├── player_stats_service.dart
    │   ├── game_realtime.dart
    │   ├── firestore_game_realtime.dart
    │   ├── game_events.dart
    │   ├── question_deadline_timer.dart
    │   └── demo/
    │       ├── demo_game_realtime.dart
    │       └── demo_synth.dart
    ├── controllers/
    │   └── daily_question_controller.dart
    ├── state/
    │   └── question_pane_controller.dart
    ├── theme/
    │   ├── app_theme.dart           # Unified theme system (all colors, HSL-based)
    │   ├── app_font.dart            # Font configuration
    │   ├── colormap.dart            # Score/percentile to color lerp (danger→success)
    │   └── layout_constants.dart    # Sizing/spacing constants
    └── widgets/
        ├── avatar_widget.dart          # Reusable avatar (SVG/raster support)
        ├── answer_accuracy_scale.dart  # Continuous logarithmic slider (1 to 999T)
        ├── slider_text_mirror.dart     # Real-time value display (e.g., "124 Million")
        ├── percentile_widget.dart      # Compact "Top X%" display with animations
        ├── unit_tape.dart              # Unit selector with locale toggle
        ├── styled_dialog.dart          # Reusable dialog with gradient borders
        ├── settings_menu.dart          # Settings menu (sign out, delete account)
        ├── animated_like_dislike.dart  # Question voting with animations
        ├── circular_determinate_spinner.dart # Progress indicators
        ├── player_widget.dart          # Avatar, status, score display
        ├── player_ring_progress.dart   # Circular countdown ring around player avatars
        ├── player_score.dart           # Animated score counter
        ├── players_row.dart            # Row layout for player chips
        ├── question_widget.dart        # Question text with tags and like widget
        ├── question_deadline_progress_tracker.dart # Deadline timer
        ├── tag_widget.dart             # Category/difficulty tags
        ├── selector_widget.dart        # Multi-option filter chips
        ├── lock_toggle_chip.dart       # Privacy toggle (public/private)
        ├── submitted_answer_chip.dart  # Displays submitted answer after reveal
        ├── rank_confetti_overlay.dart  # Game-end confetti
        ├── player_confetti_overlay.dart # Per-question confetti
        └── categories/
            └── category_carousel_m3.dart
```

### Key Principles

- **Thin API layer**: Routers handle HTTP concerns and delegate to services.
- **Service layer**: Contains all business logic and orchestration.
- **Clear separation**: Keep Firestore logic out of widgets. Use `services/` (e.g., `GameRealtime`).
- **Controller-driven state**: Thin screens, controller-driven state (`ChangeNotifier`).
- **Presentational widgets**: Receive plain values and callbacks; no service deps.
- **Error UX**: Show a `SnackBar` or blocking `AlertDialog`; never fail silently.

---

## Authentication & API Integration

### Authentication Flow

The app supports two authentication modes: **anonymous** (default) and **permanent accounts** (email/Google).

#### Anonymous Authentication (Default)

1. **Automatic Sign-In**: On first launch (after onboarding), if no user exists, the app automatically signs in anonymously via `AuthService.signInAnonymously()`.
2. **Seamless Experience**: Anonymous users can immediately play games without creating an account.
3. **Account Upgrade**: Anonymous users can upgrade to a permanent account via the settings menu:
   - Settings menu shows "Create Account" button for anonymous users
   - Navigates to `AuthScreen` which uses `SignInScreen` from `firebase_ui_auth`
   - Firebase automatically links the anonymous account with the new credential (email/password or Google)
   - Firebase UID remains the same, preserving all game data and progress
4. **Token Exchange**: Anonymous users exchange Firebase ID tokens for backend access tokens just like regular users.

#### Permanent Account Authentication

1. User signs in via `firebase_ui_auth` screens (email/password or Google).
2. `AuthService.exchangeToken()` exchanges the Firebase ID token for a backend access token (JWT) via `POST /auth/token`.
3. `ApiService` includes the access token in all subsequent requests as `Authorization: Bearer <ACCESS_TOKEN>`.

#### Common Flow (Both Anonymous and Permanent)

4. Game endpoints used by `MainScreenController`:
   - `GET /game/config` → font; categories with theme and pictures; difficulties
   - `POST /game/get_player_stats` → percentile stats (used to compute a 0..100 percentile int)
   - `POST /game/create` or `POST /game/join_random` → returns `IdModel { resource_id }`
   - Firestore game `state` is a numeric enum (e.g., 2=LOBBY_READY, 3=QUESTION_N, 4=QUESTION_N_FINISHED). The client parses numeric codes.
5. Question vote endpoints (IdModel body + response):
   - `POST /question/upvote`, `/question/de_upvote`, `/question/downvote`, `/question/de_downvote`.
   - Units: questions expose `units` as `UnitInfo` per region (US/EU). UI displays `abbreviation` in the unit tape and full names in the selector popup; submissions send the unit `id` (or `null` when unitless). The locale toggle (integrated into the unit selector popup) lets users switch US/EU, which persists via `POST /user/set_locale` and triggers a backend fetch for updated unit options.

#### Account Linking

When an anonymous user signs in with email/Google from the upgrade screen:
- Firebase UI Auth automatically handles credential linking via `CredentialLinked` action
- The anonymous account is upgraded to a permanent account
- All game data associated with the Firebase UID is preserved
- `AuthService.linkWithCredential()` can also be used programmatically for custom linking flows

### API Service

`ApiService` issues authorized HTTP requests with `Authorization: Bearer <ACCESS_TOKEN>`. All successful responses return a `200 OK` status code. Errors are communicated via standard `4xx` and `5xx` status codes with a JSON body containing a `detail` field.

### Subscription Management

The app integrates with RevenueCat for in-app purchases and subscription management via the `purchases_flutter` SDK.

#### Configuration

| Item | Value |
|------|-------|
| SDK Package | `purchases_flutter` |
| Entitlement ID | `Guesstimate Pro` |
| Offering | `default` |
| Products | `$rc_monthly`, `$rc_annual`, `$rc_lifetime` |

#### Service

`SubscriptionService` (`lib/services/subscription_service.dart`) handles:
- SDK initialization with platform-specific API keys
- User login/logout synced with Firebase UID
- Entitlement checking (`isPro`)
- Fetching offerings for paywall display
- Purchase and restore flows

#### API Keys

API keys are injected via `--dart-define` at build time:
- `REVENUECAT_ANDROID_API_KEY`: Google Play API key (starts with `goog_*`)
- `REVENUECAT_IOS_API_KEY`: App Store API key (starts with `appl_*`)

#### User Flow

1. On app launch, `SubscriptionService.initialize()` configures the SDK
2. After Firebase auth, `SubscriptionService.login(firebaseUid)` links the user
3. User navigates to Settings → Subscription to open `PaywallScreen`
4. `PaywallScreen` fetches offerings and displays available packages
5. User taps a package → `purchasePackage()` completes the purchase
6. On success, entitlements are immediately active (RevenueCat handles receipt validation)
7. RevenueCat sends webhook to backend to sync subscription status to database

#### Critical: Firebase UID Sync Requirement

**`SubscriptionService.login(firebaseUid)` must be called after every auth state change** to ensure purchases are attributed to the correct user. This includes:

| Event | Location | Why |
|-------|----------|-----|
| Anonymous sign-in | `main.dart:_ensureAuthenticated()` | Initial app launch |
| `UserCreated` | `app_router.dart:_buildSignInScreen()` | New account via email/Google |
| `SignedIn` | `app_router.dart:_buildSignInScreen()` | Returning user sign-in |
| `CredentialLinked` | `app_router.dart:_buildSignInScreen()` | Anonymous → permanent upgrade |
| `CredentialLinked` | `app_router.dart:_buildUpgradeAccountScreen()` | Upgrade from settings |
| `SignedIn` | `app_router.dart:_buildUpgradeAccountScreen()` | Sign-in from upgrade screen |

**Failure to call `login()` after credential linking** will cause purchases to be attributed to the anonymous RevenueCat user ID instead of the Firebase UID, breaking webhook user lookups.

The `login()` method is safe to call multiple times with the same UID (RevenueCat handles this gracefully).

#### Paywall Screen

`PaywallScreen` (`lib/screens/paywall_screen.dart`) displays available subscription packages:
- Fetches offerings from RevenueCat
- Shows package title, description, and price
- Handles purchase flow and error states
- Returns `true` on successful purchase for navigation handling

#### Testing

- **Sandbox Testing**: Use Google Play sandbox (test accounts in Play Console License testing)
- **Sandbox Renewals**: Subscriptions renew every 5 minutes in sandbox mode
- **No Real Charges**: License tester accounts are never charged

---

## Real-time Game State

The entire state of a game is stored in a document within the `games` collection in Firestore. The frontend subscribes to real-time updates for the current game document to reflect changes in the UI.

### GameRealtime Interface

The realtime adapter (`services/firestore_game_realtime.dart`) streams:
- Revealed question content from `games/{game_id}/questions/{question_uid}` and selects units from the locale's list in the `units` map (`US`/`EU`).
- Players' submissions/scores from `games/{game_id}/players_results/{question_uid}`.
- Question's duration in seconds from `question_duration_s`.

Lobby → Question navigation occurs automatically when the game state changes to `QUESTION_N`/`QUESTION_LAST` (driven by Firestore `games/{game_id}` updates).

### Firestore Adapter

The Firestore adapter scopes subcollection queries to the current question id and uses revealed gating:
- Questions: `games/{gameId}/questions/{question_uid}` filtered by `documentId == question_uid` AND `revealed == true`.
- Answers: `games/{gameId}/answers/{question_uid}` filtered similarly.
- Players results: `games/{gameId}/players_results/{question_uid}` filtered similarly.

This ensures the pane always displays the currently active question's revealed assets and avoids stale documents.

**Units:**
- The backend sends units as a map: `{ "US": [UnitInfo], "EU": [UnitInfo] }` where `UnitInfo = {id, name, abbreviation}`. The UI currently displays `US` options only.
- The `QuestionPane` shows `abbreviation` and menu names, but when submitting, the unit `id` is sent when present. For unitless questions, the UI leaves `unit` empty and the API layer treats it as `null`.

### Demo Adapter

`lib/services/demo/demo_game_realtime.dart` provides a deterministic demo adapter for local development that simulates game events without requiring backend connectivity.

---


## Widget Documentation

### Core Answer Display Widgets

#### AnswerAccuracyScale

**Purpose**: Displays answers on a logarithmic scale with animated reveal functionality.

**Features**:
- **Logarithmic scale**: Range 0-15 (representing 1 to 1 Trillion)
- **Tick marks**: Shows ticks for each order of magnitude with labels (K, M, B, T)
- **Dual indicators**: User answer (static) and correct answer (animated)
- **Text boxes**: Displays formatted values above/below the scale
- **Scientific notation**: Automatically uses scientific notation for out-of-bounds values
- **Animated reveal**: Correct answer indicator spawns from user answer and animates to correct position

**Usage**: Replaces the legacy `AnswerMirrorText` widget in `GameCard`. Used in Question Screen V2 for displaying and revealing answers.

**Props**:
- `currentAnswer`: Current user input (AnswerValue)
- `submittedAnswer`: Submitted answer after lock (AnswerValue?)
- `revealedAnswer`: Correct answer at reveal time (AnswerValue?)
- `revealedColor`: Color for reveal animation (Color?)
- `editable`: Whether the question is still editable (bool)

#### PercentileWidget

**Purpose**: Compact "Top X%" display with animated digit transitions.

**Features**:
- **Inverted percentile**: Displays `100 - percentile` as "Top X%"
- **Animated digits**: Smooth transitions when percentile changes
- **Color mapping**: Inverted color scale (1% = success/best, 99% = danger/worst)
- **Compact layout**: 24px height, borderless, transparent background
- **Typography**: "Top" (12px, weight 400) + digits (16px, weight 600) + "%"

**Usage**: Main screen percentile panel and question screen player percentile display.

**Props**:
- `percentile`: Percentile value 0-100 (int?)
- `visible`: Visibility control without layout shifts (bool)
- `animate`: Enable/disable digit animations (bool)

### UI Components

#### SettingsMenu

**Purpose**: Settings menu overlay with user account actions.

**Features**:
- **Sign out**: Signs out current user and returns to auth screen
- **Delete account**: Deletes user account with confirmation dialog
- **Styled dialog**: Uses `StyledDialog` for confirmation prompts
- **Error handling**: Shows SnackBar for errors

**Usage**: Accessible from main screen via settings FAB button.

---

## Screen Architecture

### Main Screen

**Purpose**: Entry point for configuring and starting/joining games.

**Controller**: `MainScreenController`
- Loads game config (categories, difficulties)
- Fetches player stats
- Handles game creation/joining
- Persists settings (category, difficulty, privacy) in-memory via `AuthService.lastRoundSettings`
- Restores settings when returning from a game

**Layout**:
- **Category carousel**: Material 3 uncontained carousel using `CarouselView`
  - Colors auto-generated client-side using formula: `hsl(startHue + i*53°, saturation, lightness)`
  - Default start color: `hsl(39°, 55%, 61%)` (based on theme's primary color)
  - Shows 3.2 cards visible with 8px spacing
  - Cards display SVG icons (colorized) and category names
  - Tap to select/deselect; selected cards show 2px colored border and subtle glow
  - Categories are nullable (no selection = "all categories")
- **Privacy toggle**: Compact lock chip showing lock/unlock icon with "Private"/"Public" label
  - Selected state (Private): Uses `secondary` color with elevated appearance
  - Unselected state (Public): Uses `textMuted` color with flat appearance
  - Positioned in top row alongside percentile panel
- **Difficulty selector**: Filter chips with `spaceBetween` alignment, center-aligned
  - Larger chips on main screen (16px font, 16x12 padding)
  - Supports deselection (null = all difficulties)

**Settings Persistence**:
- Current implementation: settings are stored in-memory on `AuthService.lastRoundSettings` and restored by `MainScreenController.initialize()` after loading config.
- Future direction: move this responsibility to a small, app-wide `UserSession`/`AppPreferences` service (constructed in `MyApp` and injected), optionally backed by `SharedPreferences` to persist across app restarts. `AuthService` should remain focused on identity, token exchange, and user profile/locale.

### Lobby Screen

**Purpose**: Shows players waiting to start; host actions for starting game; public or private invite flows.

**Controller**: `LobbyScreenController`
- Subscribes to game document
- Manages player list
- Handles host actions (start game, remove players)
- Share functionality for private games

**Behavior**:
- Public games: a spinner is shown throughout the lobby (both `LOBBY_NOT_READY` and `LOBBY_READY`) until the host starts the game.
- Private games: a Share button opens the native share sheet using `share_plus`. If `join_url` is missing, a SnackBar informs the user.
- Start button: enabled only for the host when `state == LOBBY_READY`.
- Players row: rendered via `PlayersRow` with centered alignment.
- Leave game: a top-left back button opens a confirm dialog; on confirm, `GameSessionController.leaveGame()` calls `POST /game/remove_player` and the app navigates to `/main`.

### Question Screen

**Status**: The app currently uses **Question Screen V2** (`question_v2/`), a redesigned version with improved architecture and visual continuity. The legacy V1 implementation has been fully migrated and removed from production code. V1 files are kept in `question_v1/` directory for reference only.

#### Question Screen V2 (Current)

**Purpose**: Orchestrates one round (or a sequence of rounds) of the Fermi game using a carousel-based design. Mirrors backend state from Firestore in near-real time, and triggers API calls to initiate state transitions (submit answer, go next).

**Key Architecture Improvements**:
- **Centralized State Management**: Single `QuestionScreenV2Controller` manages all game state and caches complete historical data for every question
- **Carousel Navigation**: Horizontal `CarouselSlider` provides visual continuity between questions
- **Historical State Caching**: Complete game history stored in-memory for seamless review mode
- **Simplified Widgets**: `GameCard` widgets receive immutable state, eliminating complex calculations

**Controller**: `QuestionScreenV2Controller`
- Single source of truth for: active question index, host flag, per-question duration, complete game history
- Caches `QuestionState` objects for every question as they're revealed
- Manages `CarouselSliderController` for programmatic navigation
- Handles both live mode (backend-driven) and review mode (user-driven)

**Layout Structure**:
- **Main Column** (top to bottom):
  1. Players row - unchanged, shows current players with scores
  2. Game carousel - horizontal carousel with dots indicator (fixed height)
  3. Quick access bar - draggable area that fills space between carousel and submit button (when editable)
  4. Main button - Submit/Next/Finish action button
- **Leave button**: Floating top-left corner (unchanged)

**Key Behavior**:
- **Live Mode**: Backend events update controller's active index, which programmatically scrolls the carousel
- **Review Mode**: User swipes update the same active index; controller provides cached state for that question
- **Visual Continuity**: Carousel provides smooth transitions between questions (no snap changes)
- **Fixed Heights**: Carousel height remains constant when feedback row appears/disappears
- **Percentile Display**: Player's answer percentile (when >= 50%) is displayed above each game card at reveal time, with smooth show/hide animation

**Files**:
- `question_screen_v2.dart`: Main screen widget; builds game cards for each question index
- `question_screen_v2_controller.dart`: Centralized state controller with per-question state caching
- `widgets/game_carousel.dart`: Carousel widget with dots indicator; uses `PageView` for navigation
- `widgets/carousel_page_wrapper.dart`: Wrapper widget using `AutomaticKeepAliveClientMixin` to preserve card state
- `widgets/game_card.dart`: Question-answer-feedback composite widget; receives state via props
- `widgets/quick_access_bar.dart`: Draggable quick-access bar for numpad input

**See**: [Question Screen V2 Deep Dive](#question-screen-v2-deep-dive) for detailed architecture.

#### Question Screen V1 (Legacy - Reference Only)

**Status**: No longer used in production. V1 files have been removed from the active codebase. Reference implementation is kept in `question_v1/` directory for historical reference only.

**Previous Architecture**:
- Distributed state: `QuestionScreenController` + multiple `QuestionPaneController` instances
- PageView-based navigation with hidden state management
- Complex synchronization between screen and pane controllers
- Review mode required manual cumulative score calculations

**Files**: See `question_v1/` directory for legacy implementation details (reference only).

**Migration Notes**:
- ✅ **Complete Migration**: Onboarding screen (`onboarding_screen.dart`) was migrated from V1 to V2, completing the full migration to V2 across the entire app
- ✅ **Legacy Cleanup**: V1 screen files (`question_screen.dart`, `question_screen_controller.dart`, `question_pane.dart`) have been removed from production code
- **Shared Utilities**: Shared utilities (`submit_bar.dart`, `pane_bindings.dart`, helpers) remain in `screens/question/` directory for use by V2
- **State Enum**: `QuestionPaneState` enum is kept in `state/question_pane_controller.dart` for use by `SubmitBar` and V2 (the controller class itself is deprecated)
- **Onboarding Integration**: Onboarding uses `QuestionScreenV2` with tutorial keys threaded through the widget tree; controller access is provided via `onControllerCreated` callback for reveal state polling

---

## Question Screen V2 Deep Dive

This section explains the Question Screen V2 architecture: centralized state management, carousel-based navigation, historical caching, and review mode implementation.

### Purpose

Question Screen V2 orchestrates one round (or a sequence of rounds) of the Fermi game using a redesigned architecture that provides visual continuity and simplified state management. It mirrors backend state from Firestore in near-real time, caches complete game history, and triggers API calls to initiate state transitions.

### Directory Layout

- `question_screen_v2.dart`: Main screen widget; arranges players row, carousel, quick-access bar, and action button in a column layout.
- `question_screen_v2_controller.dart`: Centralized orchestration controller (`ChangeNotifier`) that delegates to specialized manager classes. Provides public API for UI and coordinates stream subscriptions.
- `controllers/` - **Manager Classes** (refactored from monolithic controller):
  - `question_state_manager.dart`: Manages question state cache, display answer priority logic, and state queries
  - `player_state_manager.dart`: Manages player controllers, player summaries, and player state updates
  - `animation_state_manager.dart`: Manages reveal animations with correct start/end values
  - `game_timer_manager.dart`: Manages all game timers (deadline, auto-next, review mode activation)
  - `confetti_manager.dart`: Manages game-end and per-question confetti state and triggers
  - `answer_submission_handler.dart`: Handles answer submission logic, validation, and unit conversion
  - `navigation_coordinator.dart`: Manages carousel navigation and question index changes
- `widgets/game_carousel.dart`: Horizontal carousel widget using `PageView` with `DotsIndicator` for question navigation.
- `widgets/carousel_page_wrapper.dart`: Wrapper widget using `AutomaticKeepAliveClientMixin` to preserve card state when scrolled away.
- `widgets/game_card.dart`: Composite widget containing question text, answer input, and feedback (like widget).
- `widgets/quick_access_bar.dart`: Draggable quick-access bar widget that fills space between carousel and submit button. Triggers numpad input when dragged up, closes bottom sheets when dragged down.
- `models/question_state.dart`: Data model for per-question state.
- `models/question_pane_state.dart`: Enum for question pane UI state.

**Related services and state**:
- `services/game_realtime.dart`: Backend-agnostic realtime interface.
- `services/firestore_game_realtime.dart`: Firestore implementation.
- `widgets/answer_accuracy_scale.dart`: Logarithmic scale answer input.
- `widgets/answer_controller.dart`: Minimal controller for reveal animations.
- `widgets/players_row.dart`: Player chips row widget.
- `widgets/submit_bar.dart`: Submit/Next/Finish action button.

### High-Level Architecture

**Refactored Controller Architecture** (as of Nov 2024):

The `QuestionScreenV2Controller` has been refactored from a monolithic 1577-line class into a lean orchestration layer (~700 lines) that delegates to specialized manager classes. This follows the Single Responsibility Principle and improves maintainability, testability, and code organization.

**Manager-Based Design**:
- **`QuestionStateManager`**: Owns the question state cache (`Map<int, QuestionState>`) and provides state query methods with correct priority logic (animation > revealed > user > default)
- **`PlayerStateManager`**: Manages player widget controllers, player summaries, and player state updates from game snapshots
- **`AnimationStateManager`**: Handles reveal animations with correct start/end values and display format conversion
- **`GameTimerManager`**: Consolidates ALL timer logic (deadline auto-submit, auto-next countdown, review mode activation delay)
- **`ConfettiManager`**: Manages game-end confetti for top 3 players and per-question confetti for highest scorers
- **`AnswerSubmissionHandler`**: Handles answer submission with validation, unit conversion (abbreviation → ID), and fallback logic
- **`NavigationCoordinator`**: Manages carousel `PageController`, question index changes, and answer controller synchronization

**Controller Responsibilities** (orchestration only):
- Initialize and coordinate all managers
- Subscribe to game stream (`watchGame`) and delegate to managers
- Bind question-specific streams (`QuestionPaneBindings`)
- Provide public API that delegates to managers
- Handle locale changes and vote actions
- Manage stream subscriptions and disposal

**State Flow**:
1. **Backend → Controller**: `watchGame` stream updates controller state
2. **Controller → Managers**: Controller delegates updates to appropriate managers
3. **Managers → State**: Managers update their internal state (question cache, player controllers, etc.)
4. **Controller → UI**: UI reads from controller's public API, which delegates to managers
5. **User Action → Controller → Managers**: User interactions call controller methods, which delegate to managers
6. **Managers → Backend**: Managers call `realtime` methods for backend updates

**Historical State Caching**:
- `QuestionStateManager` stores complete state for every question in `Map<int, QuestionState>`
- UI widgets receive immutable state from the controller; no complex calculations in widgets
- **Per-Question State Retention**: Each question maintains its own state (`userAnswer`, `submittedAnswers`, `scores`, etc.) that persists as cards scroll away

**Carousel Navigation**:
- Uses `PageView` with `PageController` for programmatic navigation
- **State Preservation**: `CarouselPageWrapper` uses `AutomaticKeepAliveClientMixin` to preserve widget state when cards scroll away
- **Live Mode**: Backend events update `_currentIndex`, controller animates carousel to that index
- **Review Mode**: User swipes update `_currentIndex`, controller provides cached state for that index
- Dots indicator shows current question position

**Answer Controller Synchronization**:
- Single `AnswerController` instance is shared across all questions
- When navigating to a new question, `_syncControllerToCurrentQuestion()` syncs the controller to that question's `userAnswer` state
- Controller sync happens in a post-frame callback to ensure widgets are ready
- Only the current editable question uses the controller; revealed questions use prop-based display values

### QuestionState Data Structure

Each question's complete state is cached in a `QuestionState` object:

```dart
class QuestionState {
  final String? questionUid;
  final String questionText;
  final List<String> tags;
  final List<String> units;
  final Map<String, String> unitOptions;
  final Map<String, String> unitAbbreviationToId;
  final Map<String, String> unitIdToAbbreviation;
  final int upvotes;
  final VoteState voteState;
  final String category;
  final AnswerValue? correctAnswer;
  final AnswerValue? userAnswer; // Current user input for this question (per-question state)
  final Map<String, AnswerValue> submittedAnswers; // playerId -> answer
  final Map<String, double> scores; // playerId -> score
  final Map<String, int> cumulativeScores;  // Cumulative up to this question
  final Map<String, double> percentiles;    // Player percentile (0.0-1.0) for this question
  final List<PlayerState> players;          // Sorted by rank
  final bool isRevealed;
  final Duration? duration;
}
```

**Key State Fields**:
- `userAnswer`: Stores the current user input for each question independently. This allows cards to retain their input state when scrolled away.
- `submittedAnswers`: Stores submitted answers per player after submission (used for display after reveal).
- `isRevealed`: Tracks whether the question has been revealed (affects display mode and editability).

### Data Flow (Happy Path)

1. Lobby navigates to `QuestionScreenV2` when game state becomes `QUESTION_N` or `QUESTION_LAST`.
2. `QuestionScreenV2Controller.attach()` subscribes to `watchGame` and initializes question state cache.
3. For each question, controller binds streams via `QuestionPaneBindings`:
   - `revealedQuestion` → caches question text/units/tags in `QuestionState`
   - `playersAnswersForQuestion` → caches submitted answers, scores, calculates cumulative scores
   - `revealsForQuestion` → caches correct answer, marks question as revealed
4. **State Initialization**: When a question becomes active, `_ensureQuestionStateInitialized()` ensures `userAnswer` is initialized (with default unit if available).
5. **Answer Controller Sync**: When navigating to a new question, `_syncControllerToCurrentQuestion()` syncs the shared `AnswerController` to that question's `userAnswer` state.
6. **Input Changes**: User input updates `userAnswer` in state for the current question via `onAnswerChanged()`.
7. Submit: User taps submit or deadline expires → controller calls `realtime.submitAnswer()`, stores answer in `_localSubmittedAnswer` and updates state.
8. Next/Finish: Host taps or auto-next timer expires → controller calls `realtime.goNext()`, backend updates game doc, controller receives new `question_number` and animates carousel.
9. **State Retention**: As cards scroll away, their state (`userAnswer`, `submittedAnswers`, etc.) remains in the `_questionStates` map, and widgets query state for any index.
10. Review Mode: Game finishes → user can swipe carousel, controller provides cached state for each question index.

### Score Animation Flow

- **Reveal Snapshot**
  `_handlePlayersAnswers()` is the single source of truth for live scoring. It calculates cumulative totals, updates controller bindings (`setRoundScore` + `setScore`), and then calls `_applyScoresToPlayerStates()` so the cached `QuestionState.players` mirrors the values feeding the animations.

- **Controller Replay**
  `PlayerWidgetController` remembers the most recent round and cumulative scores. When a `PlayerWidget` binds (e.g., first question render), it immediately replays those values so the animation isn't lost if the reveal arrived before the widget built.

- **Widget Reconciliation**
  `PlayerWidget` reads `PlayerState.roundScore` to show the transient “+N” chip, and clears it as soon as the controller reports a zero round score (when the host advances). This keeps the cycle: baseline 0 → reveal animation → next question reset.

### Timer System

**GameTimerManager**:
All timer logic is encapsulated in `GameTimerManager`, which exposes methods to start/stop timers and streams/callbacks for events.

**Deadline Timer (Auto-Submit)**:
- Uses `QuestionDeadlineProgressTracker` to track progress from 0.0 to 1.0
- Starts when question becomes active (in `_handleQuestion()` or `_onQuestionIndexChanged()`)
- Stops when question is revealed or user manually submits
- On expiration: Automatically calls `_handleDeadlineExpired()` which submits current answer with unit mapping fallbacks
- Progress displayed in `SubmitBar` as a color gradient (blue → red)
- Timer only runs in live mode, not review mode

**Auto-Next Timer**:
- 10-second countdown timer that starts after question is revealed
- Updates `_autoNextProgress` every 100ms (0.0 to 1.0)
- Only runs for non-last questions in live mode
- On expiration: Automatically calls `requestNext()` (host only)
- Cancelled when host manually presses Next or when moving to next question
- Progress displayed in `SubmitBar` as a circular determinate indicator (top-right corner)
- Timer callback verifies question is still revealed and current index hasn't changed

### Review Mode Implementation

**Triggered when**: `GameState` is `QUESTION_LAST_FINISHED` or `GAME_FINISHED`.

**Key Features**:
- **Deterministic Navigation**: User swipes update `_currentIndex`, controller looks up cached `QuestionState` for that index
- **Score Updates**: `_updatePlayersForIndex()` replays the cached cumulative totals via `setScore()` so review mode reuses the same animation path
- **Player Reordering**: Players sorted by rank from cached state for that question
- **Bidirectional**: Works correctly when swiping forward or backward
- **State Preservation**: All question states remain accessible; cards retain their revealed state when scrolled away

**Implementation**:
- All question states cached as they're revealed during gameplay
- Review mode simply looks up cached state: `_questionStates[index]`
- Player controllers updated with `setScore(cumulativeScore)` and `setRoundScore(roundScore)`
- No backend calls needed in review mode (all data cached)
- Cards display their preserved state immediately when scrolled back into view

### GameCard Widget Structure

Each `GameCard` contains:
- **Question-Answer Card** (with border):
  - Question widget (text + tags, no border)
  - Answer accuracy scale (logarithmic slider for answer input)
  - Slider text mirror (displays current value)
  - Unit tape (unit selector with locale toggle)
- **Feedback Row** (appears after reveal, same styling as card):
  - Like/dislike widget (right-aligned)

**Height Management**: Card height remains constant when feedback row appears/disappears (uses `AnimatedContainer` with height animation).

**State Preservation**:
- Each `GameCard` is wrapped in `CarouselPageWrapper` which uses `AutomaticKeepAliveClientMixin` to preserve widget state when scrolled away
- Cards query state for their specific index via `controller.getQuestionState(index)`, `controller.getDisplayAnswer(index)`, etc.
- Each card maintains its own `userAnswer` state in the controller's `_questionStates` map
- When a card scrolls back into view, it displays its preserved state immediately (no re-initialization needed)

### Controllers and State

**QuestionScreenV2Controller**:
- Manages carousel controller (`PageController`)
- Caches historical state (`Map<int, QuestionState>`) - each question maintains independent state
- Coordinates live mode (backend-driven) and review mode (user-driven)
- Provides state to UI widgets via getters that accept any question index (not just current)
- **State Query Methods**: `getQuestionState(index)`, `getDisplayAnswer(index)`, `getPlayersForIndex(index)` allow widgets to query state for any question
- **Answer Controller Management**: Single `AnswerController` instance shared across questions; synced to current question's state when navigating
- `_applyScoresToPlayerStates()` keeps the player list aligned with reveal snapshots so UI props and controller animations never diverge
- `_updatePlayers()` still contains the pre-reveal fallback path; it intentionally mirrors `_applyScoresToPlayerStates()`. Leave that duplication unless the team explicitly green-lights the consolidation.

**AnswerController Synchronization**:
- Single `AnswerController` instance is created in `attach()`
- Only the current editable question uses the controller (via `currentAnswerController` getter)
- When navigating between questions:
  1. `_onQuestionIndexChanged()` is called
  2. `_ensureQuestionStateInitialized()` ensures state exists for the new question
  3. `_syncControllerToCurrentQuestion()` syncs controller to the new question's `userAnswer` in a post-frame callback
- Revealed questions and non-current questions use prop-based display values (via `getDisplayAnswer()`)

**Display Answer Priority System**:
The `getDisplayAnswer(index)` method uses a priority system to determine what value to display:
1. **Animation Progress**: If question is actively animating (`_animatingQuestionIndex == index`), return current animation progress
2. **Revealed Answer**: If question is revealed and not animating, return the correct answer
3. **User Answer**: If question is current, editable, and not revealed, return `userAnswer` from state
4. **Default**: Fallback to default empty answer

**Animation State Management**:
- Separate from cached state: `_animatingQuestionIndex` tracks which question is currently animating
- `_animationProgress` map stores intermediate animation values during reveal
- Animation state is cleared when animation completes or when navigating away

**PlayerWidgetController** (Enhanced):
- Stores latest round + cumulative scores and replays them on bind
- Animates score changes deterministically for both live and review mode
- Used by controller to update player scores when navigating review mode

### Visual Continuity

**Carousel Transitions**:
- Smooth horizontal scrolling between questions (no snap changes)
- Dots indicator shows current position
- Programmatic navigation uses `animateToPage()` with 500ms easeInOut

**Theme System**:
- All UI elements use `AppTheme` for consistent colors across the application
- No category-based color transitions; unified theme throughout

### Current Implementation Status

**✅ Completed**:
- Core architecture and state management
- Carousel widget with dots indicator
- GameCard widget structure
- Historical state caching
- Review mode foundation
- Navigation integration
- Answer widget controller binding
- Score continuity across questions (fixed)
- Quick access drag indicator (fixed)
- OM selector height reset (fixed)

**⚠️ In Progress** (See `docs/QS_V2_NEXT_STEPS.md` and `docs/QS_V2_REMAINING_FIXES_PROMPT.md`):
- Answer widget reveal animation fixes
- Review mode answer display fixes
- Auto-submit on deadline expiration
- Auto-next timer integration
- Unit options notifier
- Score color calculation
- Theme system unified (completed)

---

## Question Screen V1 Deep Dive (Legacy - Reference Only)

This section documents the legacy V1 implementation for reference. V1 is no longer used in production.

### Purpose

The Question screen orchestrates one round (or a sequence of rounds) of the Fermi game. It mirrors backend state from Firestore in near-real time, and triggers API calls to initiate state transitions (submit answer, go next). It contains minimal client logic: the UI reflects the backend's authoritative state.

### Directory Layout

- `question_screen.dart`: Screen container; owns paging via a PageView carousel, renders a persistent `PlayersHeader` (top) and `SubmitBar` (bottom), and attaches the screen-level controller.
- `question_screen_controller.dart`: Screen controller (`ChangeNotifier`) that listens to the game doc, derives the active page index, host flag, and per-question duration.
- `question_pane.dart`: A simple StatefulWidget that hosts the `QuestionPaneController` and builds the per-question body (question text/input). Header and footer live persistently in the screen.
- `widgets/submit_bar.dart`: Submit / Next / Finish primary action.
- `widgets/question_pane_body.dart`: Presentational body for the question text + answer input.
- `widgets/players_header.dart`: Presentational row of player chips.
- `widgets/pane_bindings.dart`: Wires per-question realtime streams (revealed question, answer, players_results) to callbacks.
- `models/`: Light UI models (e.g., `question_view_model.dart`).

**Related services and state**:
- `services/game_realtime.dart`: Backend-agnostic realtime interface (used by both screen and pane).
- `services/firestore_game_realtime.dart`: Firestore implementation; maps game doc + subcollections to typed snapshots. Units are provided as `UnitInfo` objects; the adapter normalizes to US abbreviations for UI, builds name→abbr menu options, and provides abbrev↔id maps for submission.
- `state/question_pane_controller.dart`: A `ChangeNotifier` that manages the state and business logic for a single question pane. This includes handling user input, managing timers, subscribing to real-time game events, and exposing the pane's state to the `QuestionPane` widget. It encapsulates the pane's lifecycle (`started` → `locked` → `finished`) and ensures idempotent transitions.

### High-Level Architecture

- Thin UI, controller-driven orchestration.
- Realtime data via `GameRealtime`:
  - Game doc: `watchGame(gameId)` → `GameSnapshot` (includes `state`, `question_number`, `question_uid`, `question_uids`, `progress.answered`, `duration` …).
  - Subcollections (current question):
    - `revealedQuestion(gameId, index)` → question text/units/tags when revealed.
    - `revealsForQuestion(gameId, index)` → correct answer + references when revealed.
    - `playersAnswersForQuestion(gameId, index)` → players' submitted answers and per-round scores when revealed.
- API triggers (`ApiService`): `/game/answer`, `/game/next_question`. UI never writes gameplay state directly to Firestore.

**Paging & visuals**:
- The screen uses a `PageView` carousel; the authoritative index from `watchGame` drives an `animateToPage` transition (≈500 ms easeInOut) to mimic natural scrolling between questions.
- On first entry, the carousel performs a one-time `SlideTransition` from the right to the first pane to suggest an initial scroll into the game.

**Notes on timing and duration**:
- The pane's deadline timer is only started when an authoritative per-question `duration` (> 0 ms) is available from the controller. If duration is 0 or missing, the pane waits (no speculative timer) until the backend provides it.

### Data Flow (Happy Path)

1. Lobby navigates to `QuestionScreen` when the game state becomes `QUESTION_N` or `QUESTION_LAST`.
2. `QuestionScreenController.attach()` subscribes to `watchGame` and keeps:
   - `currentIndex = snapshot.questionNumber - 1` (derived from the authoritative 1-based number; if missing, derived from `question_uid` within `question_uids`).
   - `isHost` and `perQuestionDuration`.
3. The active `QuestionPane` (matching `currentIndex`) binds three streams via `QuestionPaneBindings`:
   - `revealedQuestion` → sets the visible question text/units/tags.
   - `playersAnswersForQuestion` → updates player chips (status/answer) and adds per-round `score.number` to running totals (and exposes the per-round score for coloring).
   - `revealsForQuestion` → shows correct answer + references and transitions pane to `finished`.
4. Submit: on tap or deadline, `QuestionPane` calls `realtime.submitAnswer()` (API), sets a local submitted value for immediate UX, and waits for backend to reflect progress and later reveal. Duplicate submissions are prevented by `QuestionPaneController`.
5. Next/Finish: host taps; `QuestionScreen` calls `realtime.goNext()` (API). Backend updates the game doc (`question_uid`, `question_number`, `state`) and reveals the next question doc. The active page/pane switches when `watchGame` emits the new `question_number`.
6. Finish behavior: on the last pane, `QuestionScreen.onFinishedAll` pops to `/main` and clears the stack.

### State Machine (Pane)

- `started`
  - Editable `AnswerAccuracyScale`, timer active once duration > 0.
  - Transitions:
    - On submit: `locked`
    - On deadline: `locked` (auto-submit current value)
- `locked`
  - Input disabled. Await reveal streams.
  - Transition:
    - On reveal: `finished`
- `finished`
  - Feedback shown; auto-next timer runs on non-last panes.
  - Host can press Next immediately; non-hosts see progress.

**Idempotent guards**:
- `handleDeadlineOnce()` ensures deadline logic runs once.
- `applyRevealOnce()` ensures reveal animation/state applies once.

### Controllers and State

**QuestionScreenController**:
- Single source of truth for: active page index, host flag, per-question duration.
- Reacts to `watchGame` snapshots and notifies the screen.

**QuestionPaneController**:
- Per-pane state machine: `started` → `locked` (after submit) → `finished` (after reveal).
- Guards one-time transitions (`applyRevealOnce`, `handleDeadlineOnce`).
- Provides explicit hooks used by the pane to ensure reveal animations are applied once and to coordinate deadline-driven auto-submit.

**PlayerWidgetController**:
- Owned by `QuestionPane` and keyed by `playerId` (map). Controllers persist across reorders and are disposed when a player disappears.
- Drives per-question round-score animations for each player chip and ensures the status visuals update smoothly.

### Player Chips and Scores

**Sorting and filtering**:
- Inactive players are filtered out of the header row.
- Active players are sorted by backend-provided `rank` ascending (1..N). A medal badge is shown for the top 3 (gold/silver/bronze).
- **Review mode**: Rank icons show final game ranks (static, don't change during reordering).
- **Live mode**: Rank icons are calculated from current sorted position.

**During answer phase**: Players display countdown rings (100% → 0%) synchronized with the question deadline. Ring colors differentiate player types (self-ring vs other-rings, host vs non-host).

**On player submission**: The submitting player's ring immediately completes to 100% with `success` color.

**On reveal of `players_results`**:
- Chip switches to show the submitted answer via `SubmittedAnswerChip` (local fallback used if backend temporarily omits it).
- The chip's background tints to the RdYlGn color map based on that player's per-question score (text is white for contrast).
- The running total score adds the round `score.number` and animates.
- Rings return to static 100% with review colors.

WatchGame updates never overwrite an already revealed answer state (prevents flicker back to previous status).

### Confetti Feedback

- **Per-question**: the player with the highest round score triggers a localized confetti animation within their `PlayerWidget` after reveal (visible to all players).
- **Game end**: when the game finishes, top 3 players see a celebratory confetti overlay at the same time rank badges appear.

### Deadlines & Auto-Submit

- `QuestionDeadlineTimer` locks answers at deadline and calls submit with the current input.
- The backend enforces a short grace period; late submissions are rejected and surfaced as SnackBars.
- The pane defers auto-submit if unit mappings are temporarily unavailable after a locale switch; it resolves abbrev→id maps as soon as the normalized units arrive and then submits. Fallback: default locale unit or unitless as a last resort.

### Review Mode

**Triggered when**: `GameState` is `QUESTION_LAST_FINISHED` or `GAME_FINISHED`.

**Behavior changes**:
- User swipe enabled on the carousel; page index is local.
- Submit/Next disabled; Finish button persists across panes and exits to Main.
- Deadlines and auto-next suppressed.
- Pane immediately reveals the correct value and applies the per-question score color to the answer display.
- Player UI mirrors the viewed question:
  - `SubmittedAnswerChip` background uses the per-question round score color.
  - Transient score text shows the per-question round score (no +/-), colored identically.
- Per-question confetti is suppressed in review mode (only shown during live gameplay).
- Game-end rank confetti persists across carousel navigation in review mode (scrolling between questions).

### Theming

- All screens and widgets use `AppTheme` for consistent colors throughout the application.
- No category-based theming; unified theme system ensures visual consistency.

**Answer reveal colors**:
- On reveal, the `AnswerAccuracyScale` animates the correct answer indicator to its position on the logarithmic scale. The unit tape hides its tap and scroll indicators.
- Player chips' submitted answer capsules use the same RdYlGn shade for background.

### Error Handling & Logging

- Transient issues are displayed via SnackBars.
- Verbose logs help trace data flow:
  - `watchGame gid=… state=… qNum=… uid=…`
  - `[rt] question/answers/players_results query gid=… (uid known/unknown …) revealed count=…`
  - `[bindings] attach/… onData index=…`

### Game States (Numeric)

- `0` PRE_LOBBY
- `1` LOBBY_NOT_READY
- `2` LOBBY_READY
- `3` QUESTION_N
- `4` QUESTION_N_FINISHED
- `5` QUESTION_LAST
- `6` QUESTION_LAST_FINISHED
- `8` GAME_FINISHED
- `9` GAME_ABORTED

### Where to Put New Logic (V2)

- Network/API changes → `services/api_service.dart`.
- Realtime mapping → `services/firestore_game_realtime.dart`.
- Screen-level state and logic → `question_screen_v2_controller.dart`.
- UI widgets → `question_screen_v2.dart` and `widgets/game_card.dart`.
- Carousel behavior → `widgets/game_carousel.dart`.

### Where to Put New Logic (V1 - Legacy)

- Network/API changes → `services/api_service.dart`.
- Realtime mapping → `services/firestore_game_realtime.dart`.
- Per-pane UI → `question_pane.dart`.
- Per-pane state and logic → `state/question_pane_controller.dart`.
- Screen-level flow/paging → `question_screen_controller.dart` + `question_screen.dart`.

### Gotchas (V2)

- Do not read Firestore directly in widgets; always go through `GameRealtime`.
- Avoid local synthesis of server state. Treat Firestore as source of truth.
- The controller is the single source of truth - widgets should read from cached state, not calculate values.
- Always check if `QuestionState` exists before accessing (use `getQuestionState(index)`).
- In review mode, use cached state only - no backend calls needed.
- Player controllers must be properly disposed when players leave.
- Ensure carousel controller is properly initialized before use.
- **State Retention**: Each question maintains its own `userAnswer` state. When navigating between questions, the answer controller is synced to the new question's state, but the old question's state is preserved in `_questionStates`.
- **Answer Controller**: Only the current editable question uses the controller. Revealed questions and non-current questions use prop-based display values from `getDisplayAnswer()`.
- **Display Answer Priority**: `getDisplayAnswer()` uses a priority system (animation > revealed > user > default). Don't bypass this method; it ensures correct display values during animations and state transitions.
- **Animation State**: Animation state (`_animatingQuestionIndex`, `_animationProgress`) is separate from cached state. Animation state is cleared when animation completes or when navigating away.

### Gotchas (V1 - Legacy)

- Do not read Firestore directly in widgets; always go through `GameRealtime`.
- Avoid local synthesis of server state. Treat Firestore as source of truth.
- Ensure subcollection queries are filtered by `documentId == question_uid` and `revealed == true`.
- Guard one-time transitions in `QuestionPaneController` to prevent duplicate animations/state flips.
- When adding UI around player chips, prefer using the pane's `controllerByPlayerId` map so animations persist across order changes and to avoid double animations.
- Avoid attempting to color the "number" status: post-reveal status uses the submitted answer chip; the per-question score is used for tinting, not for replacing the answer view.

---

## Answer Input System

The answer input system has been simplified to use a continuous logarithmic slider as the primary input method, complemented by a unit selector for dimensional questions.

### Structure

- **Primary Input**: `AnswerAccuracyScale` - A continuous logarithmic slider spanning 1 to 999T (Trillion)
- **Unit Selection**: `UnitTape` - Displays current unit and opens bottom sheet selector when tapped
- **Value Display**: `SliderTextMirror` - Real-time text display of slider value (e.g., "124 Million")
- **Layout**: Horizontal row with `SliderTextMirror` (left) and `UnitTape` (right), positioned below the slider
- **Model**: `AnswerValue` (from `models/answer_value.dart`) represents complete answer state

### Continuous Logarithmic Slider

The `AnswerAccuracyScale` widget provides a continuous logarithmic scale for answer input:

- **Range**: 1 to 999T (10^0 to 10^15)
- **Precision**: Any integer value from 1-999 within each order of magnitude
- **Examples**: 1, 42, 157, 999, 1K, 42K, 157K, 999K, 1M, etc.
- **Interaction**: Tap or drag to select value
- **Visual Feedback**: Real-time position indicator and value display
- **Scale Labels**: K, M, B, T markers at major tick positions

### Value Display (SliderTextMirror)

The `SliderTextMirror` widget displays the current slider value in human-readable format:

- **Format**: Number + order of magnitude word (e.g., "42 Thousand", "157 Million")
- **Special Cases**: Values 1-999 display as just the number (e.g., "42", "157")
- **Styling**: Uses `AppFont` for consistent typography
- **Updates**: Real-time synchronization with slider position
- **Location**: Left side of answer row, below the slider

### Unit Selection (UnitTape)

The `UnitTape` widget handles unit display and selection:

- **Display**: Shows current unit abbreviation (e.g., "km", "mi")
- **Interaction**: Tap to open bottom sheet selector
- **Selector**: Full unit names with locale toggle (US/EU)
- **Locale Toggle**: Integrated "U.S. Units" checkbox in selector
- **Backend Sync**: Switching locale fetches new unit options via API
- **Unitless Questions**: Hidden automatically when no units available
- **Location**: Right side of answer row, below the slider

### Pre-Reveal Theming (AppTheme-Based)

- Slider track: `border` color
- Slider thumb: `info` color (blue accent)
- Slider labels: `textMuted`
- Mirror text: `text` color
- Unit tape text: `textMuted`
- Unit tape background: Transparent
- Tap indicators: `border` color (fade out on reveal)

### Reveal Behavior

- Slider animates to correct answer position
- Revealed answer indicator appears with score-based color
- Submitted answer indicator shows player's answer
- Mirror text freezes to show submitted value (for comparison)
- All text colors change to score-interpolated color (danger→success gradient)
- Tap indicators fade out
- The displayed correct value is taken from `players_results.{player_id}.correct_answer` (already in the user's locale/unit)

### Unit & Locale Handling

- Unit selector shows full names (e.g., "Mile", "Kilometer") in bottom sheet popup
- Unit tape displays abbreviations (e.g., "mi", "km")
- Locale toggle integrated into unit selector popup as "U.S. Units" checkbox
- Switching locale fetches new unit options from backend; selector updates reactively
- When unitless questions, unit tape is hidden automatically

### Screen Adaptation

- Bottom sheet selectors slide screen content upward via `Matrix4.translationValues`
- Combined offset: `keyboardHeight + bottomSheetHeight`
- Submit button and progress indicators remain visible
- Smooth animations synchronized with keyboard timing (100ms linear)
- `BottomSheetHeightProvider` tracks custom bottom sheet heights

### Answer Mirror Text Behavior

During reveal, the mirror text freezes to show the player's submitted answer (making it easy to compare against the animated correct answer on the slider). Resumes live mirroring on the next question.


---

## Theming System

### AppTheme (Primary Theme)

All colors come from AppTheme - backgrounds, text, borders, semantic colors:

- Access via `Theme.of(context).extension<AppTheme>()` or `AppTheme.defaultTheme()`
- Colors defined using HSL values for maintainability
- Background colors: `bgDark`, `bg`, `bgLight`
- Text colors: `text`, `textMuted`
- UI elements: `highlight`, `border`, `borderMuted`
- Brand colors: `primary`, `primaryMuted`, `secondary`, `secondaryMuted`
- Semantic colors: `danger`, `warning`, `success`, `info`
- Score-to-color mapping uses `Color.lerp` between `danger` (low scores) and `success` (high scores)

### Theme Consistency

All UI elements use `AppTheme` for consistent colors:
- Background colors: `bgDark`, `bg`, `bgLight`
- Text colors: `text`, `textMuted`
- UI elements: `highlight`, `border`, `borderMuted`
- Brand colors: `primary`, `primaryMuted`, `secondary`, `secondaryMuted`
- Semantic colors: `danger`, `warning`, `success`, `info`

### Player Status Chip Readability

The `SubmittedAnswerChip` dynamically picks a contrasting text color against its score-colored background (danger→success gradient) using `utils/color_contrast.dart` to ensure readability.

### Question Tags and Voting

- **Tags**: appear at the end of the question text in the scrollable area, styled chips with 8px spacing and subtle vertical dividers (1px, `border` color at 30% opacity)
- **Like widget**: appears after reveal at the bottom-right corner (outside scrollable area)
- **Tag styling**: `border` color text, light weight

### Question Copy Feature

After reveal (or in review mode), users can:
- Long-press the question widget to copy the text
- Tap the copy icon (top-right of question widget) for instant copy
- Material 3 ripple effect provides visual feedback on press

### Question Voting (Like/Dislike)

Enhanced animated voting buttons integrated in question widget:
- Smooth color transitions (secondary→primary for upvote, secondary→danger for downvote)
- Bubble and circle animations on tap (Material-style feedback)
- Subtle glow effect on filled state
- Vote count updates with smooth animation
- Positioned on the right side of the tags row (bottom-aligned)

### Visual Feedback for Top 3 Finishers

When the game ends, players who finish in 1st, 2nd, or 3rd place see a celebratory confetti animation:
- Rank is determined by position in the sorted player list (from the last question's state)
- Confetti style varies by rank (gold/silver/bronze colors, higher density for better ranks)
- Animation emits particles for 6 seconds, then lets them naturally fall off screen (~12 seconds total)
- Appears at the same time as rank badges (when game enters review mode)
- Persists across carousel navigation in review mode (scrolling between questions) until animation completes

### Per-Question Highest Scorer Feedback

After each question, the player with the highest score for that question gets a localized confetti animation on their widget:
- Small (3-6px) multicolor confetti particles
- Clipped to the player's widget bounds (100x160 area) - visible to all players
- Low blast force and high drag keep particles contained within the widget
- Emits for 4 seconds, then particles naturally fall off (~8 seconds total)
- Automatically clears when moving to next question

### Player Status Indicators

Player chips communicate state through circular progress rings rendered around their avatars via the `PlayerRingProgress` widget:

**Ring Types**:
- **Self-ring**: The current player's ring (colored `primary` if host, otherwise `info`)
- **Other-rings**: Opponent player rings (colored `border` for neutral appearance)

**Ring States** (managed via `RingState` enum):
- **Countdown**: Rings animate deterministically from 100% → 0% during the answer window, synchronized with the question deadline timer. All player rings animate together to show remaining time.
- **Completed**: When a player submits their answer, their ring immediately completes to 100% and turns `success` color, while other players' rings continue counting down.
- **Review**: In review mode or after reveal, rings display as static 100% progress with their base colors (self-ring uses `info`, other-rings use `border`, host ring uses `primary`).

**Implementation Details**:
- Ring progress is passed as a live parameter through the widget tree (`QuestionPaneController` → `PlayersHeader` → `PlayersRow` → `PlayerWidget` → `PlayerRingProgress`) to ensure smooth 50ms animation updates.
- Ring state is computed per-player based on game phase and submission status.
- The `PlayerRingProgress` widget wraps the avatar with a `CircularProgressIndicator` (4px stroke width, 4px gap).
- Ring progress updates are synchronized with `QuestionDeadlineProgressTracker` for consistent countdown across all players.

**Additional Status Indicators**:
- **Score badge & answer chip**: Per-question scores surface via the animated score badge and submitted answer chip after reveal.
- **Status overlays**: Removed legacy "waiting" dots spinner and "ready" green checkmark in favor of the ring system.

---

## Visual Behaviors

### Screen-Level Background

Screens use consistent `AppTheme` gradient backgrounds throughout. Backgrounds are not animated between screens; navigation transitions use slide animations instead.

### Carousel Transition

Between questions, the screen animates `PageView.animateToPage` with a ~500 ms easeInOut curve, producing a natural horizontal scroll effect.

On first show, the `PageView` is wrapped in a one-time `SlideTransition` from `Offset(0.45, 0)` to `Offset.zero` to mimic an initial scroll-in.

### Feedback Area Animation

The reserved feedback area animates between feedback (post-reveal) and locale toggle (pre-answer) using `AnimatedSwitcher` with custom slide-in/out (up on enter, down on exit) and fade.

### Answer Reveal

At reveal time, the `AnswerAccuracyScale` shows the correct answer indicator at its position on the logarithmic scale. The color is derived from the local player's per-question score using the RdYlGn color map.

### Confetti

- **Per-question**: highest round scorer's `PlayerWidgetController` triggers localized confetti inside the player widget bounds. Only shown during live gameplay (suppressed in review mode).
- **Game end**: top 3 players see rank-themed confetti at the same time rank badges appear. Confetti persists across carousel navigation in review mode until the animation completes (~12 seconds).

### Screen Navigation Transitions

- **Main → Lobby**: Slide transition from right to left (300ms, easeInOut)
- **Lobby → Question**: Slide transition from right to left (300ms, easeInOut)
- All transitions use equal forward and reverse durations for consistent UX

---

## Development Guidelines

### Component Patterns

- Keep Firestore logic out of widgets. Use `services/` (e.g., `GameRealtime`).
- Thin screens, controller-driven state (`ChangeNotifier`).
- Presentational widgets receive plain values and callbacks; no service deps.
- `PercentileWidget` receives a resolved integer (0..100) and owns range validation and ordinal suffix rendering.
- Error UX: show a `SnackBar` or blocking `AlertDialog`; never fail silently.

### State Management Principles

- Controllers orchestrate view state (loading, timers, navigation) and derive all gameplay state from streams.
- Avoid duplicating or synthesizing server state on the client.
- Single source of truth is always the backend (Firestore + API).

### Where to Put New Logic

- Add UI affordances in presentational widgets under `widgets/`.
- Extend controller-observed fields by updating `GameSnapshot` and the Firestore adapter mapping.
- New per-question streams: add to `GameRealtime`, implement in `firestore_game_realtime.dart`, and bind in `pane_bindings.dart`.
- Support EU units: pass a user/system setting to pick `units['EU']` in the adapter and thread through `QuestionPaneBody`.

### Safe Extension Points

- Add per-question UI in `widgets/` and drive it from `QuestionPaneController` fields.
- Add new realtime signals by extending `GameRealtime`, implementing them in the Firestore adapter, and binding via `QuestionPaneBindings`.
- Extend screen-level flow by enhancing `QuestionScreenController`; avoid putting streams in the screen widget.
- Theme changes belong in `AppTheme` and its `lerp` method.

### Gotchas and Best Practices

- Do not read Firestore directly in widgets; always go through `GameRealtime`.
- Avoid local synthesis of server state. Treat Firestore as source of truth.
- Ensure subcollection queries are filtered by `documentId == question_uid` and `revealed == true`.
- Guard one-time transitions in `QuestionPaneController` to prevent duplicate animations/state flips.
- When adding UI around player chips, prefer using the pane's `controllerByPlayerId` map so animations persist across order changes and to avoid double animations.
- Never assume units; always convert using adapter maps.
- Avoid double animations by honoring `handleDeadlineOnce()` and `applyRevealOnce()`.
- Guard against missing duration by deferring the timer start.

---

## Design Decisions

### Why Controller-Driven Architecture?

- **Separation of concerns**: Business logic lives in controllers, widgets remain presentational
- **Testability**: Controllers can be tested independently of UI
- **Reusability**: Same controller can drive multiple widget implementations
- **State clarity**: Single source of truth per screen/component

### Why Backend-Agnostic GameRealtime?

- **Flexibility**: Enables Firestore-backed prod and deterministic demo adapters
- **Testing**: Demo adapter allows local development without backend
- **Abstraction**: UI doesn't depend on specific backend implementation
- **Future-proofing**: Easy to swap out Firestore if needed

### Why Client-Side Deadline Enforcement?

- **Reduces server load**: No active polling required
- **Better UX**: Local countdown provides immediate feedback
- **Server validates but doesn't enforce**: Trade-off: trust client to submit on time
- **Graceful degradation**: Backend has short grace period for late submissions

### Why Anonymous Authentication?

- **Reduced barrier to entry**: Users can start playing immediately without account creation
- **Seamless upgrade path**: Anonymous accounts can be upgraded to permanent accounts without data loss
- **Preserved user experience**: All game data is preserved when upgrading (Firebase UID remains constant)
- **Flexible user journey**: Users can try the app before committing to account creation

### Why Dual Storage (PostgreSQL + Firestore)?

From backend architecture:
- **Firestore**: Real-time synchronization, automatic conflict resolution, scalable for concurrent games
- **PostgreSQL**: Complex queries for question selection, materialized views for analytics, relational integrity

---

## Deep Links & Cross-Platform Invites

The app supports cross-platform invite links that work seamlessly across web, Android, and iOS platforms.

### URL Structure

Invite URLs use API trampoline endpoints that detect the platform and redirect appropriately:

- **Game Invites**: `{API_BASE_URL}/api/v1/game/invite/{game_id}`
- **Daily Question**: `{API_BASE_URL}/api/v1/daily_question/invite/{YYYY-MM-DD}`

The trampoline pages detect the user's platform and:
- **Android**: Use intent URIs for reliable app launching (handles Chrome/WebView edge cases)
- **iOS**: Use custom scheme with App Store fallback
- **Other**: Use custom scheme with Play Store fallback

### Platform Behavior

| Platform | Behavior |
|----------|----------|
| **Web Browser** | Trampoline redirects to custom scheme; if app not installed, falls back to app store |
| **Android (app installed)** | Intent URI launches app directly via Android system |
| **iOS (app installed)** | Custom scheme launches app |
| **Mobile (no app)** | Redirects to appropriate app store after timeout |

### Implementation

**DeepLinkService** (`lib/services/deep_link_service.dart`):
- Handles both custom scheme (`guesstimate://`) and HTTPS URLs
- Parses URL paths to extract game IDs or DQ dates
- Stores pending invites for post-authentication handling
- On web, checks initial URL path on app load

**Backend URL Generation**:
- Game service generates invite URLs using `request.base_url` (dynamically adapts to environment)
- Daily Question service generates invite URLs using `request.base_url`
- Frontend transforms `localhost` to `10.0.2.2` for Android emulator testing

**Native App Configuration**:

- **Android**: `AndroidManifest.xml` includes intent filters for `guesstimate://` custom scheme
- **iOS**: `Info.plist` includes URL scheme configuration
- Custom scheme URLs: `guesstimate://invite/{game_id}`, `guesstimate://dq/{date}`

### Flow

1. User shares invite link (generated by backend using request's base URL)
2. Recipient clicks link
3. Browser loads trampoline page from API
4. Trampoline detects platform and redirects:
   - Android: Uses intent URI for reliable app launch
   - iOS: Uses custom scheme with fallback
5. App receives deep link via `app_links` package
6. `DeepLinkService` parses URL and triggers appropriate navigation
7. If user not authenticated, invite is stored as pending
8. After authentication, pending invite is processed

### Local Development

For Android emulator testing:
- Backend serves trampoline at `http://10.0.2.2:8000/api/v1/game/invite/{id}`
- Frontend transforms `localhost` URLs to `10.0.2.2` before sharing
- Intent URIs ensure Chrome reliably launches the app

### Backwards Compatibility

The app maintains support for legacy custom scheme URLs (`guesstimate://invite/{id}`) for backwards compatibility with existing shared links.

---

## Related Documentation

- [Frontend README](../README.md): Quick start and running locally
- [Deployment Guide](DEPLOYMENT.md): Build and deployment processes
- [Question Screen V2 Next Steps](../../docs/QS_V2_NEXT_STEPS.md): Implementation guide for completing V2
- [Question Screen V2 Design Doc](../../docs/QS_v2.md): Original design requirements
- [Fermi API README](../../fermi-api/README.md): Backend API reference
- [Fermi API Architecture](../../fermi-api/docs/ARCHITECTURE.md): Game state and flow details
- [Main Project README](../../../README.md): Project overview and structure

## Migration Notes

### Question Screen V1 → V2

The app has migrated from Question Screen V1 to V2. Key differences:

**Architecture**:
- **V1**: Distributed state (screen controller + multiple pane controllers)
- **V2**: Centralized state (single controller with historical cache)

**Navigation**:
- **V1**: Hidden PageView with complex state synchronization
- **V2**: Visible CarouselSlider with direct state mapping

**Review Mode**:
- **V1**: Manual cumulative score calculations, error-prone
- **V2**: Deterministic lookup from cached state

**Visual Flow**:
- **V1**: Snap changes between questions
- **V2**: Smooth carousel transitions

The legacy V1 implementation is kept in `question/` directory for reference but is no longer used in production. See `docs/QS_V2_NEXT_STEPS.md` for remaining implementation tasks.
