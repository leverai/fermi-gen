# Fermi Game API

FastAPI backend for The Fermi Game providing authentication, game management, and user endpoints.

## Documentation

- **README** (this file): Quick start and API endpoint reference
- **[Architecture](docs/ARCHITECTURE.md)**: Game flow, state management, and design decisions
- **[Deployment](docs/DEPLOYMENT.md)**: Cloud Run deployment and configuration
- **[Fermi DB Schema](../../packages/fermi-db/docs/SCHEMA.md)**: Database table definitions
- **[Main Project README](../../README.md)**: Project overview

## Table of Contents

- [Documentation](#documentation)
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Authentication](#authentication)
- [Real-time Game State](#real-time-game-state)
- [API Endpoints](#api-endpoints)
  - [Auth Endpoints](#auth-endpoints)
  - [Game Endpoints](#game-endpoints)
  - [Question Endpoints](#question-endpoints)
  - [User Endpoints](#user-endpoints)
- [Game Flow Walkthrough](#game-flow-walkthrough)

## Overview

The backend is a FastAPI application that exposes a RESTful API for game management. The game's real-time state is managed in a Firestore `games` collection, which clients should listen to for live updates. The API is used to initiate state changes, and Firestore is used to broadcast them.

All successful responses return a `200 OK` status code. Errors are communicated via standard `4xx` and `5xx` status codes with a JSON body containing a `detail` field.

For detailed architecture, game flow, and state management, see **[Architecture Documentation](docs/ARCHITECTURE.md)**.

## Quick Start

### Running Locally

```bash
# From workspace root
make up-api
```

API will be available at `http://127.0.0.1:8000/api/v1`

**API Documentation:**
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

### Testing

```bash
# Unit tests
make test-api-unit

# Integration tests (requires Docker + emulators)
make test-api-integration

# API endpoint tests
make test-api
```

## Authentication

Authentication is handled via JWT bearer tokens. Clients must first authenticate with Firebase and then exchange their token for a JWT access token via the `/auth/token` endpoint.

**Flow:**
1. Client authenticates with Firebase → receives Firebase ID token
2. Client calls `POST /auth/token` with Firebase token
3. Backend verifies token, creates/updates user in database
4. Backend returns JWT access token
5. Client includes JWT in all future requests: `Authorization: Bearer <ACCESS_TOKEN>`

For complete details, see **[Architecture Documentation](docs/ARCHITECTURE.md#authentication--authorization)**.

## Real-time Game State

The entire state of a game is stored in a Firestore `games` collection document. The frontend subscribes to real-time updates for the game document and queries subcollections (`questions`, `answers`, `players_results`) where `revealed=true`.

**Key Concepts:**
- Game document contains top-level fields (state, players, progress, etc.)
- Subcollections contain questions, answers, and results
- Progressive revelation: documents have a `revealed` boolean field
- Frontend listens to `revealed=true` queries only

**Game States:**
- `LOBBY_NOT_READY` (1): Waiting for questions to be fetched
- `LOBBY_READY` (2): Ready to start
- `QUESTION_N` (3): Question in progress
- `QUESTION_N_FINISHED` (4): Question completed, waiting for next
- `QUESTION_LAST` (5): Last question in progress
- `QUESTION_LAST_FINISHED` (6): Game over
- `GAME_FINISHED` (8): Officially ended
- `GAME_ABORTED` (9): Aborted (all players left)

For complete schema details, see **[Architecture Documentation](docs/ARCHITECTURE.md#real-time-game-state)**.

## API Endpoints

All game-related endpoints are prefixed with `/api/v1/game`.

### Auth Endpoints

#### `POST /auth/token`
Exchanges a Firebase ID token for a JWT access token.

-   **Request:**
    -   **Headers:** `Authorization: Bearer <FIREBASE_ID_TOKEN>`
-   **Response (200 OK):** `TokenResponse`
    ```json
    {
      "access_token": "string",
      "token_type": "bearer",
      "user": {
        "firebase_uid": "string",
        "email": "string",
        "display_name": "string",
        "picture": "string"
      }
    }
    ```
-   **Errors:**
    -   `401 Unauthorized`: If the Firebase token is invalid or expired.

#### `POST /auth/refresh`
Refreshes a JWT access token.

-   **Request:**
    -   **Headers:** `Authorization: Bearer <ACCESS_TOKEN>` (the existing access token; may be expired)
-   **Response (200 OK):** `TokenResponse`
    ```json
    {
      "access_token": "string",
      "token_type": "bearer",
      "user": {
        "firebase_uid": "string",
        "email": "string",
        "display_name": "string",
        "picture": "string"
      }
    }
    ```
-   **Errors:**
    -   `401 Unauthorized`: If the token is invalid or has an invalid signature/user.


#### `POST /auth/sign-out`
Sign out.

-   **Request:** (No body)
-   **Response:** 200

### Game Endpoints

All game endpoints require a valid JWT access token in the `Authorization` header.

#### `GET /game/config`
Retrieves the game configuration, including requestable categories (with theming and pictures) and the list of difficulties.

-   **Request:** (No body)
-   **Response (200 OK):** `GameConfigResponse`
    ```json
    {
      "categories": [
        {
          "index": 0,
          "name": "PLANET_EARTH",
          "slug": "Planet Earth",
          "theme": {
            "background": "0xFF94B4A9",
            "foreground": "0xFFF7F5E3",
            "foreground_negative": "0xFFF4C851",
            "foreground_p30": "0x4DF7F5E3",
            "foreground_negative_p30": "0x4DF4C851"
          },
          "picture": "https://<host>/static/categories/PLANET_EARTH.png"
        }
        // ... additional CategoryInfo objects
      ],
      "difficulties": [
        {
          "name": "EASY",
          "slug": "Easy",
          "picture": "https://<host>/static/difficulties/snai.svg"
        }
        // ... additional DifficultyInfo objects
      ]
    }
    ```

Notes:
- `categories` uses a RequestCategory enum that excludes `OTHER`.
- `picture` is an absolute URL served by the backend at `/static/categories/<NAME>.png`.
- `slug` is a human‑readable display name for the frontend.

#### `POST /game/create`
Creates a new private game. The user who creates the game becomes the host.

-   **Request Body:** `GameCreateRequest`
    ```json
    {
      "question_round_settings": {
        "n_questions": 6,
        "category": "PLANET_EARTH", // RequestCategory value; use None for all categories
        "difficulty": "MEDIUM"       // or null
      }
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Side Effects:**
    -   A new game document is created in Firestore.
    -   A background task is started to fetch questions for the game. The `state` field will be updated to `LOBBY_NOT_READY` initially, and then to `LOBBY_READY` when the questions are fetched.

#### `POST /game/join`
Joins a specific game by its ID.

-   **Request Body:** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Errors:**
    -   `404 Not Found`: If the game does not exist.
    -   `409 Conflict`: If the game has already started or is full.
-   **Side Effects:**
    -   The new player is added to the `players` map in the game document, and the `state` is set to `LOBBY_NOT_READY`.
    -   A background task is started to re-fetch questions. The `state` will be updated to `LOBBY_READY` when done.

#### `POST /game/start`
Starts the game. This can only be done by the host.

-   **Request Body:** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Errors:**
    -   `403 Forbidden`: If the user is not the host.
    -   `409 Conflict`: If the game is not in a startable state (e.g., `LOBBY_READY`).
-   **Side Effects:**
    -   The game `state` is updated to `QUESTION_N` (or `QUESTION_LAST` if there's only one question) in Firestore, and the first question document in the `questions` subcollection has its `revealed` field set to `true`.

#### `POST /game/answer`
Submits an answer for the current question.

-   **Request Body:** `GameAnswerRequest`
    ```json
    {
      "resource_id": "string",
      "answer": {
        "number": 1000,
        "unit": "meter" // unit id from UnitInfo; use null for unitless
      }
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Errors:**
    -   `409 Conflict`: If the question deadline has passed or the player has already answered.
-   **Side Effects:**
    -   The player's answer is recorded in the `players_results` subcollection.
    -   If all active players have answered, the game `state` is updated to `QUESTION_N_FINISHED` (or `QUESTION_LAST_FINISHED`), and the `revealed` field is set to `true` on the corresponding `answers` and `players_results` documents.

#### `POST /game/next_question`
Moves the game to the next question. This can only be done by the host.

-   **Request Body:** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Errors:**
    -   `403 Forbidden`: If the user is not the host.
    -   `409 Conflict`: If the game is not in a state where it can move to the next question (e.g., `QUESTION_N_FINISHED`).
-   **Side Effects:**
    -   The game `state` is updated to `QUESTION_N` or `QUESTION_LAST`, and the next question document in the `questions` subcollection has its `revealed` field set to `true`.

#### `POST /game/remove_player`
Removes a player from the game. This can be done by the host, or by a player to remove themselves.

-   **Request Body:** `GameRemovePlayerRequest`
    ```json
    {
      "resource_id": "string",
      "player_id": "string"
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Errors:**
    -   `403 Forbidden`: If a user tries to remove another player and is not the host.
-   **Side Effects:**
    -   If the game has not started, the player is removed from the `players` map.
    -   If the game has started, the player's `is_active` field in the `players` map is set to `false`.
    -   If the host leaves, another player is promoted to host.
    -   If no active players are left, the game is ended.

#### `POST /game/end`
Ends the game. This can only be done by the host.

-   **Request Body:** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Response (200 OK):** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Errors:**
    -   `403 Forbidden`: If the user is not the host.
-   **Side Effects:**
    -   The game `state` is set to `GAME_FINISHED` in Firestore.
    -   A background task is started to archive the game results to the database.

#### `POST /game/get_player_stats`
Retrieves the current authenticated user's statistics.

-   **Request Body:** None (empty body `{}`). The endpoint automatically uses the authenticated user's Firebase UID from the JWT token.
-   **Response (200 OK):** `GetPlayerStatsResponse`
    ```json
    {
      "player_id": "string",
      "stats": {
        "total_party_games": 42,
        "total_daily_guesses": 15,
        "average_percentile": 75,
        "rank": {
          "id": 3,
          "name": "Analyst",
          "picture": "https://<host>/static/ranks/3.svg"
        },
        "level": 1
      }
    }
    ```

Notes:
- `total_party_games`: Number of party mode games the player has participated in
- `total_daily_guesses`: Number of daily questions the player has answered
- `average_percentile`: Overall average percentile across all party games (0-100)
- `rank`: Player rank based on average percentile, includes:
  - `id`: Tier ID (1-5)
  - `name`: Tier name (Observer, Guesstimator, Analyst, Strategist, Fermi Master)
  - `picture`: URL to the rank image
- `level`: Player level (always 1, not yet implemented)

**Rank Tiers:**
| Tier | Percentile Range | Name |
|------|------------------|------|
| 1 | 0-39% | Observer |
| 2 | 40-74% | Guesstimator |
| 3 | 75-89% | Analyst |
| 4 | 90-97% | Strategist |
| 5 | 98-100% | Fermi Master |

#### `POST /question/upvote` and `POST /question/downvote`
Set or toggle a user's vote on a question. The backend stores per‑user votes in a `questions_votes` table. Upvote/downvote counts are computed from this table; there are no aggregate counters on `fermi_questions`. The resulting verdict is returned.

-   **Request Body:** `IdModel`
    ```json
    {
      "resource_id": "string"
    }
    ```
-   **Response (200 OK):** `VoteVerdictResponse`
    ```json
    {
      "resource_id": "string",
      "verdict": 1  // 1 = upvote, 0 = no vote, -1 = downvote
    }
    ```

Notes:
- Only two endpoints exist for voting: `/question/upvote` and `/question/downvote`.
- Toggle rules when calling these endpoints repeatedly:
  - current: UPVOTE; action: DOWNVOTE -> verdict: NO_VOTE (0)
  - current: NO_VOTE; action: DOWNVOTE -> verdict: DOWNVOTE (-1)
  - current: NO_VOTE; action: UPVOTE -> verdict: UPVOTE (1)
  - current: DOWNVOTE; action: UPVOTE -> verdict: NO_VOTE (0)

---

### Daily Question Endpoints

The Daily Question (DQ) mode serves a single question to all users daily with synchronized timing and leaderboard functionality.

**Key Concepts:**
- Window: 8 AM - 8 PM US Central Time
- Answer Deadline: 30 seconds after starting (or window end, whichever is sooner)
- Grace periods: 5s after AD, 20s after window end
- All timestamps in UTC (converted at API layer)
- Separate storage from Party mode

#### `GET /daily_question/status`
Get the current daily question status and timing information.

-   **Request:** (No body)
-   **Response (200 OK):** `DQStatusResponse`
    ```json
    {
      "window_status": "ACTIVE",  // NOT_STARTED, ACTIVE, CLOSED
      "seconds_until_window_end": 3600.5,
      "question_date": "2025-12-15",
      "user_status": "NOT_STARTED",  // NOT_STARTED, IN_PROGRESS, SUBMITTED, MISSED
      "has_results": false
    }
    ```

#### `POST /daily_question/start`
Start the daily question for the current user. Returns the question with deadline.

-   **Request:** (No body)
-   **Response (200 OK):** `DQQuestionResponse`
    ```json
    {
      "question": {
        "question_uid": "uuid-string",
        "text": "How many...",
        "category": "PLANET_EARTH",
        "difficulty": "MEDIUM",
        "unit_hint": "kilometers"
      },
      "answer_deadline_utc": "2025-12-15T20:30:45.123Z",
      "seconds_to_answer": 30.0
    }
    ```
-   **Errors:**
    -   `409 Conflict`: Window closed or user already started

#### `POST /daily_question/answer`
Submit an answer for the daily question.

-   **Request Body:** `DQAnswerRequest`
    ```json
    {
      "answer": {
        "number": 100,
        "unit": "kilometers"
      }
    }
    ```
-   **Response (200 OK):** `DQSubmitResponse`
    ```json
    {
      "submitted": true,
      "score": 85.5,
      "message": "Answer submitted successfully. Results available after 8 PM CT."
    }
    ```
-   **Errors:**
    -   `409 Conflict`: Deadline passed, not started, or already submitted

#### `GET /daily_question/results`
Get results for today's daily question (available after window closes).

-   **Request:** (No body)
-   **Response (200 OK):** `DQResultsResponse`
    ```json
    {
      "question_date": "2025-12-15",
      "question_uid": "uuid-string",
      "question_text": "How many...",
      "correct_answer": {
        "number": 100,
        "unit": "kilometers"
      },
      "user_answer": {
        "number": 95,
        "unit": "kilometers"
      },
      "user_score": 85.5,
      "user_rank": 42,
      "total_participants": 150,
      "leaderboard": [
        {
          "rank": 1,
          "display_name": null,
          "score": 100.0,
          "time_taken_s": 15.2
        }
      ]
    }
    ```
-   **Errors:**
    -   `409 Conflict`: Results not yet available

#### `GET /daily_question/history`
Get the user's past daily question results (only DQs the user participated in).

-   **Request:** Query parameter `limit` (default: 30)
-   **Response (200 OK):** `DQHistoryResponse`
    ```json
    {
      "history": [
        {
          "question_date": "2025-12-14",
          "question_text": "How many...",
          "user_answer": {
            "number": 95,
            "unit": "kilometers"
          },
          "correct_answer": {
            "number": 100,
            "unit": "kilometers"
          },
          "score": 85.5,
          "rank": 42,
          "total_participants": 150
        }
      ]
    }
    ```

#### `GET /daily_question/archive`
Get all past daily questions with user participation status (for carousel and archive view).

Unlike `/history`, this endpoint returns **all** closed DQs regardless of whether the user participated, making it suitable for displaying the full DQ timeline in the UI.

-   **Request:** Query parameter `limit` (default: 30)
-   **Response (200 OK):** `DQArchiveResponse`
    ```json
    {
      "items": [
        {
          "question_date": "2025-12-14",
          "question_text": "How many...",
          "total_participants": 150,
          "user_participated": true,
          "user_score": 85.5,
          "user_rank": 42
        },
        {
          "question_date": "2025-12-13",
          "question_text": "What is the...",
          "total_participants": 200,
          "user_participated": false,
          "user_score": null,
          "user_rank": null
        }
      ]
    }
    ```

**Key differences from `/history`:**
- Returns all closed DQs, not just user's participated DQs
- Includes `user_participated` boolean flag
- `user_score` and `user_rank` are `null` if user didn't participate
- Designed for carousel/archive UI that shows all DQs

### User Endpoints

#### `POST /user/delete`
Deletes the authenticated user and all associated data from the database.

-   **Request:** (No body)
-   **Response (200 OK):** Literal[200]
-   **Errors:**
    -   `401 Unauthorized`: If the access token is missing or invalid.
-   **Side Effects:**
    -   The user record is deleted from the `user` table.
    -   All associated data is deleted:
        -   `user_question_history` entries for the user
        -   `answer_events` entries for the user
        -   `questions_votes` entries for the user
    -   The operation is idempotent: calling it multiple times has no additional effect after the first successful deletion.

#### `POST /user/set_locale`
Setting the user's locale to US/EU

-   **Request Body:** `SetLocaleRequest`
    ```json
    {
      "locale": "string"
    }
    ```
-   **Response (200 OK):** Literal[200]

### Assets Endpoints

#### `GET /assets/avatars`

-   **Request:** (No body)
-   **Response (200 OK):** `GetAvatarsResponse`


### Local Testing

For local development and testing, use the `manage_dq.py` script to manage daily questions:

```bash
# List available DQ questions
python scripts/manage_dq.py list

# Create today's daily question (picks next available question)
python scripts/manage_dq.py create

# Manually start the DQ window (set status to ACTIVE)
python scripts/manage_dq.py start

# Manually end the DQ window (set status to CLOSED)
python scripts/manage_dq.py end

# Advance to next day: close current DQ, shift date back, create new DQ
python scripts/manage_dq.py advance

# Mark some fermi questions as daily question candidates
python scripts/manage_dq.py seed --count 10
```

**Testing Workflow:**
1. Start with a clean slate: `make run-frontend` uses `--no-dq-history` flag to avoid creating past DQ entries
2. Create today's DQ: `python scripts/manage_dq.py create`
3. Test the active DQ flow
4. To test history/archive: Use `python scripts/manage_dq.py advance` to create past DQs

---

## Game Flow Walkthrough

1.  **Authentication:** The user authenticates with Firebase, then calls `POST /auth/token` to get an access token.
2.  **Configuration:** The frontend calls `GET /game/config` to get available categories and difficulties to display in the UI.
3.  **Create/Join Game:**
    -   The user selects game settings and calls either `POST /game/create` for a private game, or `POST /game/join_random` for a public game.
    -   Alternatively, if the user has a game ID, they can call `POST /game/join`.
4.  **Lobby:**
    -   The frontend receives the `game_id` and subscribes to the corresponding game document in Firestore.
    -   The UI updates in real-time as other players join (by observing the `players` map) and the game `state` changes (e.g., to `LOBBY_READY` when questions are fetched).
5.  **Start Game:**
    -   The host calls `POST /game/start`.
    -   The frontend listens for the game `state` to change to `QUESTION_N` and then queries the `questions` subcollection for the document with `revealed: true`.
6.  **Answering Questions:**
    -   Players submit their answers via `POST /game/answer`.
    -   The frontend listens for updates to the `progress` field in the game document to see who has answered.
    -   When the game `state` changes to `QUESTION_N_FINISHED`, the frontend queries the `answers` and `players_results` subcollections for the revealed documents to display the results.
7.  **Next Question:**
    -   The host calls `POST /game/next_question`.
    -   The cycle repeats from step 6.
8.  **End of Game:**
    -   After the last question, the game `state` becomes `QUESTION_LAST_FINISHED`.
    -   The host can end the game at any time by calling `POST /game/end`.
    -   The final scores and rankings are displayed.
