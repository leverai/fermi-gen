# Survival Mode

Single-player mode where players answer timed questions until they fail.

## Overview

- **Game Flow**: Start/Resume → Answer → Pass/Fail → Request Next (if passed) / Game Over (if failed)
- **Timer**: 40 seconds per question (+20s server-side grace period)
- **Pass Threshold**: Score must meet or exceed p50 (median) to continue
- **No Firestore**: All state managed in PostgreSQL

## Database

### `survival_runs` Table

| Column | Type | Description |
|--------|------|-------------|
| `id` | int | Primary key |
| `user_firebase_uid` | str | User identifier (indexed) |
| `started_at` | datetime | Run start time |
| `ended_at` | datetime | Run end time (null if active) |
| `questions_answered` | int | Count of questions answered |
| `total_score` | float | Cumulative score |
| `current_question_uid` | str | Current question (required, indexed) |
| `current_deadline` | datetime | Answer deadline (nullable) |
| `is_completed` | bool | True if run ended |

### Unified Data Storage

Survival uses shared tables with Party mode:
- **`answer_events`**: Answers stored with `game_id=run_id` (int)
- **`user_question_history`**: Updated after each answer (synchronously)

This ensures:
- Player rank includes both Party and Survival answers
- XP and analytics work consistently across modes

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/survival/create_or_resume` | POST | Start new run OR resume/advance active run |
| `/survival/answer` | POST | Submit answer, get pass/fail result |
| `/survival/stats` | GET | Get user's survival statistics |
| `/survival/streak` | GET | Get user's streak stats (current and best streak) |

### Voting
Use existing question endpoints:
- `POST /question/upvote` with `question_uid`
- `POST /question/downvote` with `question_uid`

## Frontend Contract

### Game Flow

1. **Start/Resume**: `POST /survival/create_or_resume` with optional `run_id`
   - Returns: `run_id`, `question_number`, `question`, `time_limit_seconds`, `answer_deadline_utc`
   - If no `run_id` provided: creates new run OR finds existing active run
   - If `run_id` provided: resumes that specific run

2. **Answer**: `POST /survival/answer` with `run_id` and `answer`
   - Returns: `passed`, `score`, `percentile`, `correct_answer`, `run_summary`
   - **Does NOT return next question** — client must call `create_or_resume` again

3. **Next Question** (if passed): `POST /survival/create_or_resume` with `run_id`
   - Returns next question with fresh deadline

4. **Game Over** (if failed): Response includes `run_summary` with final stats

### Deadline Enforcement

- Server sets `answer_deadline_utc` per question
- Client should display 40-second countdown
- Server allows 20-second grace period for network latency
- Past grace period → answer rejected with error

## Key Differences from Party Mode

| Aspect | Party | Survival |
|--------|-------|----------|
| Players | Multiplayer | Single player |
| Sync | Firestore real-time | PostgreSQL only |
| Questions | All at once | One at a time |
| Next Question | Bundled in answer response | Separate request |
| History Update | Batch at game end | Per question (sync) |
| Answer Storage | `answer_events` | `answer_events` (shared) |

## Feature Gating

### Free Tier Limits

- **Runs Per Day**: 2 runs per calendar day (UTC midnight reset)
- Limit checked only when **creating new runs**, not resuming
- Pro users have unlimited runs

### Backend Enforcement

- `SurvivalRunRepository.get_runs_remaining_today()` counts today's runs
- `SurvivalService.create_or_resume_run()` checks limit before creating new runs
- Returns `403 Forbidden` with `"Daily survival run limit reached"` if exceeded
- `GET /user/limits` returns `survival_runs_remaining` field (-1 for Pro users)

### Frontend Enforcement

- `PreSurvivalScreen` fetches limits and checks `canPlaySurvival`
- Shows "Get Unlimited" button → opens paywall when limit reached
- Resuming an active run bypasses the limit check
- `GamesTab` Survival card shows "N free runs left today" for free users
