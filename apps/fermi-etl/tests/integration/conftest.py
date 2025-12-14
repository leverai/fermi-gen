"""Integration test fixtures for fermi-etl.

Provides database setup, cleanup, and API client for end-to-end testing.
"""

import asyncio
import os
from collections.abc import Generator
from pathlib import Path

import fermi_db.models  # noqa: F401 - Ensure models are registered
import pytest
import sqlalchemy as sa
from dotenv import load_dotenv
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel import SQLModel


@pytest.fixture(scope='session', autouse=True)
def _load_env() -> None:
    """Load `.env` from fermi-etl directory for integration tests."""
    # apps/fermi-etl/tests/integration/ -> parents[2] is apps/fermi-etl
    env_path = Path(__file__).resolve().parents[2] / '.env'
    if env_path.exists():
        load_dotenv(env_path, override=False)


@pytest.fixture(scope='session', autouse=True)
def _verify_database_reachable() -> None:
    """Fail fast if DATABASE_URL is missing or DB is unreachable.

    Ensures integration tests run against Postgres via asyncpg rather than
    silently falling back to SQLite.
    """
    db_url = os.environ.get('DATABASE_URL')
    assert db_url, (
        'DATABASE_URL is not set. Use `make test-etl-integration` or export\n'
        'DATABASE_URL=postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db'
    )
    assert db_url.startswith('postgresql+asyncpg://'), (
        'DATABASE_URL must use asyncpg driver for integration tests:\n'
        'expected prefix postgresql+asyncpg://'
    )

    async def _ping() -> None:
        eng = create_async_engine(db_url, echo=False)
        try:
            async with eng.connect() as conn:  # type: ignore[call-arg]
                await conn.execute(sa.text('SELECT 1'))
        finally:
            await eng.dispose()

    try:
        asyncio.run(_ping())
    except Exception as exc:  # pragma: no cover - environment guard
        raise AssertionError(
            'Postgres is not reachable at DATABASE_URL. Ensure docker compose db\n'
            'service is up and listening on 127.0.0.1:5433.',
        ) from exc


async def _truncate_pipeline_tables_async() -> None:
    """Truncate pipeline tables to ensure DB isolation per test.

    Excludes alembic_version and fermi_questions (seed data).
    Uses TRUNCATE ... RESTART IDENTITY CASCADE on PostgreSQL.
    """
    # Pipeline tables to truncate (not fermi_questions which is seed data)
    pipeline_tables = [
        'seeds',
        'seeds_usage',
        'raw_questions',
        'fermi_answers',
    ]

    db_url = os.environ.get('DATABASE_URL', 'sqlite+aiosqlite:///./fermi.db')
    engine = create_async_engine(db_url, echo=False)
    async with engine.begin() as conn:
        dialect = conn.dialect.name
        if dialect in ('postgresql', 'postgres'):
            table_names = ', '.join(f'"{t}"' for t in pipeline_tables)
            # Add fermi_questions to the list - we want to truncate it for ETL tests
            await conn.execute(
                sa.text(
                    f'TRUNCATE TABLE {table_names}, "fermi_questions" '
                    'RESTART IDENTITY CASCADE',
                ),
            )
        else:
            # Fallback for SQLite or other databases
            for table_name in [*pipeline_tables, 'fermi_questions']:
                # Get the table from metadata
                for t in SQLModel.metadata.sorted_tables:
                    if t.name == table_name:
                        await conn.execute(t.delete())
    await engine.dispose()


def _truncate_pipeline_tables_sync() -> None:
    """Wrap for truncating tables."""
    asyncio.run(_truncate_pipeline_tables_async())


@pytest.fixture(autouse=True)
def _reset_db_before_each_test() -> None:
    """Reset the database state between tests (truncate pipeline tables)."""
    _truncate_pipeline_tables_sync()


@pytest.fixture(scope='session')
def api_client() -> Generator[TestClient, None, None]:
    """Provide TestClient for fermi-etl app with lifespan enabled.

    Ensures CWD is `apps/fermi-etl` so imports and relative paths work.
    """
    # Ensure CWD is apps/fermi-etl
    prev = Path.cwd()
    try:
        etl_dir = Path(__file__).resolve().parents[2]
        os.chdir(etl_dir)

        import importlib

        main = importlib.import_module('main')

        with TestClient(main.app) as c:
            yield c
    finally:
        os.chdir(prev)


@pytest.fixture(scope='session', autouse=True)
def _dispose_engine_at_end() -> Generator[None, None, None]:
    """Dispose the database engine at the end of the test session."""
    return
    # Engine disposal handled automatically on process exit
    # Manual asyncio.run() disposal causes event loop conflicts
