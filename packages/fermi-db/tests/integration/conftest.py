"""Integration test fixtures for fermi-db.

These tests need a real Postgres with the pgvector extension: SQLite cannot
execute ``cosine_distance`` (``<=>``), so the similarity floor and the distance
ordering cannot be validated in-memory. Bring up the compose ``db`` service and
point ``DATABASE_URL`` at a Postgres+pgvector database, e.g.::

    docker compose up -d db
    docker compose exec -T db psql -U postgres -c 'CREATE DATABASE "fermi-db";'
    export DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db

The session fixture runs the Alembic migrations against that database, so the
``fermi.embedding`` column and ``smart_search_events`` table exist.
"""

import asyncio
import os
from collections.abc import AsyncGenerator
from pathlib import Path

import fermi_db.models  # noqa: F401 - ensure models are registered
import pytest
import pytest_asyncio
import sqlalchemy as sa
from alembic import command
from alembic.config import Config
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlmodel.ext.asyncio.session import AsyncSession

# Repo root: packages/fermi-db/tests/integration/conftest.py -> parents[4]
# (integration -> tests -> fermi-db -> packages -> repo root).
_REPO_ROOT = Path(__file__).resolve().parents[4]

# Tables this suite owns; truncated between tests for isolation.
_OWNED_TABLES = ('smart_search_events', 'user_question_history', 'fermi')


@pytest.fixture(scope='session', autouse=True)
def _verify_database_reachable() -> None:
    """Skip the whole suite cleanly when no pgvector Postgres is configured.

    These tests need a real Postgres+pgvector (SQLite can't run ``cosine_distance``),
    so when ``DATABASE_URL`` is unset/non-asyncpg or the DB is unreachable we
    *skip* rather than fail — a plain ``pytest`` / CI run without the compose db
    service stays green. Point ``DATABASE_URL`` (asyncpg driver) at a pgvector
    Postgres to actually run them. This is a session-scoped autouse fixture, so it
    gates ``_migrate`` and ``session`` too.
    """
    db_url = os.environ.get('DATABASE_URL')
    if not db_url or not db_url.startswith('postgresql+asyncpg://'):
        pytest.skip(
            'No pgvector Postgres configured '
            '(set DATABASE_URL=postgresql+asyncpg://...); '
            'skipping fermi-db integration tests.',
        )

    async def _ping() -> None:
        eng = create_async_engine(db_url, echo=False)
        try:
            async with eng.connect() as conn:
                await conn.execute(sa.text('SELECT 1'))
        finally:
            await eng.dispose()

    try:
        asyncio.run(_ping())
    except Exception:  # pragma: no cover - environment guard
        pytest.skip(
            'Postgres not reachable at DATABASE_URL; '
            'skipping fermi-db integration tests.',
        )


@pytest.fixture(scope='session', autouse=True)
def _migrate(_verify_database_reachable: None) -> None:
    """Run Alembic migrations to head against the test database (once).

    Uses Alembic's in-process API from the repo root. ``script_location`` in the
    root ``alembic.ini`` is relative to the repo root, so cwd is set there and the
    option is re-asserted (Config may not resolve it from the file under pytest).
    env.py reads ``DATABASE_URL`` from the environment. This fixture is sync, so
    env.py's ``asyncio.run`` has no running loop to clash with.
    """
    prev_cwd = Path.cwd()
    try:
        os.chdir(_REPO_ROOT)
        cfg = Config('alembic.ini')
        cfg.set_main_option('script_location', 'packages/fermi-db/alembic')
        command.upgrade(cfg, 'head')
    finally:
        os.chdir(prev_cwd)


@pytest_asyncio.fixture
async def session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a clean AsyncSession; truncate owned tables before each test."""
    db_url = os.environ['DATABASE_URL']
    engine = create_async_engine(db_url, echo=False)
    async with engine.begin() as conn:
        table_names = ', '.join(f'"{t}"' for t in _OWNED_TABLES)
        await conn.execute(
            sa.text(f'TRUNCATE TABLE {table_names} RESTART IDENTITY CASCADE'),
        )

    maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with maker() as s:
        yield s
    await engine.dispose()
