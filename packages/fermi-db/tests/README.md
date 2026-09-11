# fermi-db tests

`fermi-db` owns the load-bearing SQL behind the product: scoring quantiles,
overall percentiles, leaderboards, vector (smart) search, and multi-table
transactions (GDPR anonymization). Most of this is **Postgres-only** —
`percentile_cont`, `percent_rank`, `DENSE_RANK`, `DISTINCT ON`,
`cosine_distance` (pgvector) — so it can only be meaningfully tested against a
real Postgres. These tests assert that behavior directly, at the layer that owns
it, instead of indirectly through the API + Firebase-emulator stack.

## Quickstart

```bash
make test-db              # unit + integration
make test-db-unit         # SQLite-only, no Docker
make test-db-integration  # real Postgres + pgvector
```

**No `docker compose up`, `DATABASE_URL`, migrate, or seed steps are required.**
The integration suite provisions its own Postgres. You only need a **running
Docker daemon**.

## How provisioning works (testcontainers)

The integration harness (`tests/integration/conftest.py`) is **dual-mode**:

- **Default (local + CI):** a `pytest-asyncio` session fixture starts an
  ephemeral `pgvector/pgvector` container via
  [testcontainers](https://testcontainers.com/), runs Alembic migrations to
  head, and tears the container down at the end of the session.
- **Bring-your-own Postgres:** set
  `DATABASE_URL=postgresql+asyncpg://…` and the harness uses that instance
  instead of starting a container (e.g. a CI service container).

Other knobs:

- `FERMI_TEST_PG_IMAGE` overrides the container image (default
  `pgvector/pgvector:pg17`).
- If Docker is unavailable **and** no `DATABASE_URL` is set, local integration
  runs skip, but CI fails closed so a missing database cannot bypass the gate.
- The harness bridges Docker Desktop / rootless Docker automatically (it reads
  the active docker context into `DOCKER_HOST` when needed), and disables the
  testcontainers Ryuk reaper (the container is stopped explicitly).

## The harness

| Fixture | Scope | What it gives you |
| --- | --- | --- |
| `database_url` | session | The asyncpg DSN (starts/stops the container). |
| `_migrate` | session | Applies Alembic migrations to head once. |
| `engine` | session | A `NullPool` async engine (see note). |
| `session` | function | A clean `AsyncSession`; **every table is truncated before each test**. |

Write a test by taking `session` and instantiating the repository directly:

```python
async def test_something(session: AsyncSession) -> None:
    repo = AnswerRepository(session)
    session.add_all([...])         # seed
    await session.commit()
    result = await repo.get_question_quantiles(uid)
    assert ...                     # assert on the observable result
```

**Why `NullPool` + a session-scoped engine?** pytest-asyncio uses a fresh event
loop per test. A pooled asyncpg connection created in one test's loop and reused
in another's raises "got Future attached to a different loop". `NullPool` keeps
every connection short-lived, so one session-scoped engine is safe and we avoid
the older "new engine per test" workaround.

**Isolation** is per-test `TRUNCATE … RESTART IDENTITY CASCADE` of every table in
the `public` schema (read from `pg_tables`, so it never drifts from a hand-kept
list). Schema is built once per session from the real migrations — including the
pgvector extension and the `fermi` table — so the tests exercise the production
schema, not `create_all`.

## Conventions

- **Test behavior, not implementation.** Assert on returned values and DB state,
  not on call counts or internal structures.
- **No paid API calls.** Smart search is tested with hand-crafted unit vectors
  (`test_smart_search.py`) — the embedding *generation* (OpenAI
  `text-embedding-3-small`) is upstream in `fermi-api` and never invoked here;
  the repository takes a `list[float]` and runs pure SQL.
- **Pin the real SQL semantics.** Where a property of the data lets you predict
  the exact output, assert it (e.g. `percentile_cont(p)` over `[0..N-1]` equals
  `p·(N-1)`), rather than re-deriving the algorithm in Python.
- **Self-contained files.** Each test module builds its own rows with small
  `_factory`-style helpers; there is no shared fixture soup.

## Coverage map

| File | Repository method(s) | Behavior pinned |
| --- | --- | --- |
| `test_smart_search.py` | `FermiRepository.get_unseen_similar_questions` | cosine floor, distance carry-out, unseen-fairness order, filters |
| `test_smart_search_migration.py` | `add_smart_search` Alembic revision | existing-row embedding backfill, telemetry enum/indexes, downgrade |
| `test_answer_repository.py` | `AnswerRepository.get_question(s)_quantiles`, `get_overall_avg_percentile(_batch)` | cold-start guard, `percentile_cont`, `percent_rank` ties, bulk emptiness contracts |
| `test_leaderboards.py` | Survival & Precision Rush `get_leaderboard` / `get_user_leaderboard_entry` | best-run-per-user, dense ranks, active-vs-completed, user-row join, time windows |
| `test_question_votes.py` | `QuestionVotesRepository.set_verdict`, `get_upvotes_bulk`, `get_players_vote_verdicts_bulk` | additive toggle, idempotency, FK guard, opposite bulk-emptiness contracts |
| `test_user_repository.py` | `UserRepository.anonymize_user`, `get_user_with_tier` | multi-table atomic rewrite, idempotency, isolation, tier resolution |
| `test_smart_search_event_insert.py` (unit) | `FermiRepository.insert_smart_search_event` | JSON serialization regression (SQLite) |

## Behaviors flagged for follow-up

These tests pin **current** behavior and call out likely bugs (so a fix becomes a
deliberate, visible change). See the docstrings for details:

- `get_overall_avg_percentile` returns **100** for a user with no games, while
  its docstring says 0 — a brand-new user showing as top percentile.

## Not yet covered (good next targets)

High-value Postgres-only logic still tested only indirectly (or not at all):
`EnrichmentRepository.sync_fermi_table` (the `fermi` materialization),
`DailyQuestionAnswerRepository` rank queries, the login-streak update, and
`FermiRepository.get_unseen_random_questions`.

## CI

`make test-db` runs in CI via `.github/workflows/fermi-db-ci.yml` (wired into the
orchestrator on any `packages/fermi-db/**` change) and gates merges.
testcontainers uses the runner's Docker daemon, so no service container is
needed.
