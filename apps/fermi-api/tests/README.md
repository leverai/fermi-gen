# **Backend Tests (Fermi API)**

This is the single source of truth for backend testing. It consolidates guidelines, fixtures, quickstart commands, and the roadmap.

## **Test Types and Scope**

- *Unit:* pure Python logic (no `TestClient`).
- *API:* lightweight HTTP tests using a minimal app (no lifespan/DB/emulators).
- *Integration:* full app with lifespan, Postgres, and Firebase emulators.

See the detailed roadmap at `apps/fermi-api/tests/ROADMAP.md`.

## **Quickstart**

- Prereqs: Python 3.11, uv, Docker
- Commands (at repo root):
  - `make test-api-endpoints` — API-only tests (no emulators/DB)
  - `make test-api-integration` — starts only the Firebase emulators with
    Compose; pytest provisions an ephemeral pgvector Postgres container,
    migrates it, runs integration tests, and cleanup tears everything down
  - `make up` / `make down` — start/stop services

## **Environment**

`make test-api-integration` exports the emulator variables below. The pytest
fixture intentionally leaves `DATABASE_URL` unset so Testcontainers can create
an isolated pgvector database. CI may instead provide an external asyncpg URL.

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
GOOGLE_CLOUD_PROJECT=fermi-local
```

The application `.env` under `apps/fermi-api/` may also contain local defaults,
but an already-provisioned test URL is never overridden:

```bash
DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
GOOGLE_CLOUD_PROJECT=fermi-local
APP_ENV=local
USE_EMULATORS=true
```

## **Guidelines**

1) Keep API-only tests isolated
- Use `tests/api` for routes that don't need DB/emulators.
- For pure request validation (e.g., 422 body errors), use `client_overrides` so dependencies (`get_current_user`, DB, Firestore) are faked and never invoked.

2) Use integration when emulators/DB are needed
- Use `tests/integration` with `api_client` to exercise startup hooks and real dependencies.
- Firestore reads use emulator REST with auth headers and short polling.

3) Determinism and cleanup
- Each integration test starts from a clean Auth/Firestore state; DB tables are truncated between tests.
- A session-scoped autouse fixture disposes the async SQLAlchemy engine at session end to avoid `asyncpg` termination after the event loop closes.

4) Utilize Existing Fixtures: Study the existing fixtures carefully to maximize reusability.

5) Firestore emulator REST requires admin headers
- When listing subcollections via the emulator REST API, include headers: `Authorization: Bearer owner` and `X-Goog-User-Project`.
- Prefer using the `list_firestore_subcollection_docs(game_id, subcollection)` fixture which sets these correctly.

6) Keep output readable
- Use the Makefile targets for quieter runs.
  - Integration: `make test-api-integration`.
  - API-only: `make test-api-endpoints`.
  - Unit: `make test-api-unit`.

## **Fixtures**

### API (`apps/fermi-api/tests/api/conftest.py`)

- `client` (FastAPI `TestClient`): mounts `api_router` at `settings.api_v1_str` without running lifespan (no DB/emulators).
- `client_overrides` (FastAPI `TestClient`): same as `client` but overrides `get_current_user`, `get_firestore_client`, `get_game_service` with fakes for validation/auth tests.

### Integration (`apps/fermi-api/tests/integration/conftest.py`)

- Autouse
  - `database_url`: uses a supplied asyncpg URL or provisions ephemeral pgvector Postgres with Testcontainers.
  - `_migrate`: upgrades the selected database to Alembic head once per session.
  - `_load_env`: loads `.env` without overriding the provisioned database URL.
  - `_verify_emulators_reachable`: fails fast if Firestore emulator isn't reachable (prevents silent hangs).
  - `_reset_emulators_before_each_test`: clears Auth users and Firestore `games/*` before each test.
  - Session end: disposes the async SQLAlchemy engine.
  - `_seed_questions_once`: seeds minimal questions into Postgres once per session for start-time question fetching.
- App/HTTP
  - `api_client`: full app `TestClient` with lifespan; fixture `chdir`s so `StaticFiles('static')` resolves.
- Emulator helpers
  - `create_emulator_user_and_get_token`: creates Auth emulator user and returns tokens via direct HTTP.
  - `get_api_auth_headers`: exchanges a Firebase emulator `idToken` for an API access token via `/auth/token`.
  - `reset_emulators`: best‑effort cleanup for known collections.
  - `get_firestore_doc`: reads `games/{id}` via emulator REST with auth headers, decodes REST types, and polls briefly until present.
  - `list_firestore_subcollection_docs`: lists doc ids under a game's subcollection (`questions`, `answers`, or `players_results`).
  - `create_private_game`: posts `/game/create` with defaults and returns the `game_id`.

### Unit (`apps/fermi-api/tests/unit/conftest.py`)

- `recorder_writer` (RecorderWriter): minimal write recorder exposing `update` and `set` to mimic Firestore batch/transaction surfaces. Unit tests assert against `recorder_writer.updates`/`sets`.
- `fake_doc_ref`: lightweight object with an `id` field used where a Firestore `AsyncDocumentReference` is expected.
- `user_factory(uid, name='n', picture=None)`: returns a user-like object with `firebase_uid`, `display_name`, and `picture` fields that match writers’ expectations.
- `players_map_factory(*uids, host=None)`: builds a `dict[str, GamePlayer]` by invoking `GamePlayersWriter._user_to_player` for each uid, flagging `is_host` when `uid == host`.

## **DB Reset Mechanism**

- Integration tests truncate all application tables before each test (`TRUNCATE ... RESTART IDENTITY CASCADE` on Postgres, fallback to per-table delete otherwise). Schema is created once via Alembic migrations when the suite starts.

## Running in CI

- Start Firebase emulators, supply CI Postgres through `DATABASE_URL`, export
  emulator variables, then run `pytest` for `tests/integration` and `tests/api`.

## Common Scenarios to Cover

- Auth: token exchange, protected route access.
- Game lifecycle: create → start → answer → next_question → end.
- Edge cases: joining twice, host leaving, correct answer ranges.

### New Integration Test
- `tests/integration/test_e2e_game_flow.py`: Full happy-path flow across create → join → start → answer all → finished. Uses existing fixtures and conservative polling (`_wait_all_answered`) to avoid flakes on eventual consistency.

## Links

- Roadmap: `apps/fermi-api/tests/ROADMAP.md`
- Backend API integration guide: `apps/fermi-api/README.md`
