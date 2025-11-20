# fermi-frontend

Flutter frontend for The Fermi Game — a real-time, multiplayer trivia experience built around estimation questions.

## Documentation

- **README** (this file): Quick start and running locally
- **[Architecture](docs/ARCHITECTURE.md)**: Detailed architecture, component design, and implementation details
- **[Deployment](docs/DEPLOYMENT.md)**: Build processes and platform-specific deployment
- **[Fermi API](../fermi-api/)**: Backend API documentation
- **[Main Project README](../../README.md)**: Project overview

## Table of Contents

- [What is this?](#what-is-this)
- [Prerequisites](#prerequisites)
- [Running Locally](#running-locally)
- [Architecture Overview](#architecture-overview)
- [Development Guidelines](#development-guidelines)
- [Troubleshooting](#troubleshooting)
- [Dependencies of Note](#dependencies-of-note)
- [Useful Links](#useful-links)

---

## What is this?

Fermi Frontend is a Flutter app for playing The Fermi Game — a real-time, multiplayer trivia experience built around estimation questions. It integrates with:
- Firebase Auth (for sign-in)
- FastAPI backend (token exchange + game endpoints)
- Firestore (real-time game state via a `GameRealtime` adapter)

---

## Prerequisites

- **Flutter + FVM**: For Flutter version management
- **Android SDK / Emulator**: Recommended for local testing
- **Firebase CLI & Emulators**: Auth + Firestore emulators
- **Backend running locally**: See project root `README.md` and `apps/fermi-api/README.md`

---

## Running Locally

### Quick Start (Full Stack)

Start all services and run the app:

```bash
# From workspace root
make run-frontend
```

This starts the database, Firebase emulators, backend API, and launches the Flutter app with emulator configuration.

### Manual Start

If you prefer manual control:

1. **Start backend services**:
   ```bash
   # From workspace root
   make up-api
   ```

2. **Start Android emulator**:
   ```bash
   emulator -avd <your_emulator_name>
   ```

3. **Run the app**:
   ```bash
   # From apps/fermi-frontend
   fvm flutter run -t lib/main.dart \
     --dart-define=USE_EMULATORS=true \
     --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
     --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
     --dart-define=API_BASE_URL=http://localhost:8000/api/v1
   ```

### Widget Demo Harness

For isolated widget development:

```bash
fvm flutter run -t lib/widget_test_harness.dart
```

---

## Architecture Overview

The frontend follows a **controller-driven architecture** with clear separation of concerns:

### Core Principles

- **Source of truth**: Firestore game document and revealed subcollections (`questions`, `answers`, `players_results`)
- **Initiate via API, propagate via Firestore**: Client actions call REST endpoints; backend updates Firestore; UI reflects changes in real-time
- **Minimal local state**: Controllers orchestrate view state and derive gameplay state from streams
- **Thin screens, fat controllers**: Screens delegate to `ChangeNotifier` controllers; widgets are presentational

### Key Components

- **Screens**: Top-level views (MainScreen, LobbyScreen, QuestionScreenV2)
- **Controllers**: State management (`MainScreenController`, `LobbyScreenController`, `QuestionScreenV2Controller`)
- **Services**: Backend adapters (`GameRealtime`, `ApiService`, `AuthService`)
- **Widgets**: Reusable presentational components (`AnswerWidget`, `PlayerWidget`, `PlayerRingProgress`, `QuestionWidget`, `GameCard`, `GameCarousel`)
- **Theme**: Centralized theming (`AppTheme`)

For complete architecture details, see **[Architecture Documentation](docs/ARCHITECTURE.md)**.

---

## Development Guidelines

### Component Patterns

- Keep Firestore logic out of widgets; use `services/` abstractions
- Thin screens, controller-driven state (`ChangeNotifier`)
- Presentational widgets receive plain values and callbacks; no service dependencies
- Error UX: show `SnackBar` or blocking `AlertDialog`; never fail silently

### State Management

- Controllers orchestrate view state (loading, timers, navigation)
- Derive all gameplay state from backend streams
- Never duplicate or synthesize server state on the client
- Single source of truth is always the backend (Firestore + API)

### Code Quality

Before committing:

```bash
# Analyze code
fvm flutter analyze

# Format code
fvm flutter format --fix .
```

### Adding New Features

1. Create a feature branch off `develop`
2. Implement changes following the architecture patterns
3. Run checks locally (`flutter analyze`, `dart format`)
4. Manually test on Android emulator with Firebase/Backend emulators
5. Open a PR with a concise description and screenshots/screencasts for UI changes

For detailed guidelines, safe extension points, and gotchas, see **[Architecture Documentation](docs/ARCHITECTURE.md#development-guidelines)**.

---

## Troubleshooting

### Stuck on Loading or 401 Errors

**Check**:
- Token exchange succeeded (check logs)
- All `--dart-define` values provided correctly
- Emulator hosts are correct
- Backend is running and accessible

### Backend Unreachable on Android Emulator

The app automatically replaces `http://localhost` with `http://10.0.2.2` for Android emulators. Ensure the backend API is running at the specified URL.

### Firestore Listener Issues

**Check**:
- Firebase emulators are running (`make up-api`)
- Project ID is `fermi-local` when using emulators
- `FIRESTORE_EMULATOR_HOST` is set correctly

### Unitless Answers

Leaving the unit empty will submit `unit: null`. Ensure backend is running with the refactor that treats unitless as null.

For complete troubleshooting guide, see **[Deployment Documentation](docs/DEPLOYMENT.md#troubleshooting)**.

---

## Dependencies of Note

- **`carousel_slider` (^5.1.1)**: Horizontal carousel widget for Question Screen V2 navigation
- **`dots_indicator` (^3.0.0)**: Dots indicator for carousel position display
- **`share_plus`**: Native share sheet for private lobby invites
- **`like_button` (v2.1.0)**: Animated like/dislike buttons with bubble and circle effects
- **`confetti`**: Celebratory confetti animations for top 3 finishers and per-question highest scorers
- **`flutter_svg`**: SVG rendering for icons and avatars
- **`flutter_typing_indicator`**: Animated dots for "waiting" player status
- **`firebase_auth`**: Firebase authentication
- **`cloud_firestore`**: Real-time database for game state
- **`firebase_ui_auth`**: Pre-built authentication UI

---

## Useful Links

- **Backend API contract and game flow**: `apps/fermi-api/README.md`
- **Backend architecture**: `apps/fermi-api/docs/ARCHITECTURE.md`
- **Frontend architecture**: `docs/ARCHITECTURE.md`
- **Question Screen V2 next steps**: `../../docs/QS_V2_NEXT_STEPS.md`
- **Question Screen V2 design**: `../../docs/QS_v2.md`
- **Deployment guide**: `docs/DEPLOYMENT.md`
- **Project overview**: `../../README.md`
