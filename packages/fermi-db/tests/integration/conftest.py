"""Integration-test harness for fermi-db.

Provisions a real Postgres + pgvector via **testcontainers** (no manual
``docker compose up``), applies Alembic migrations once, and hands each test a
clean ``AsyncSession`` with every table truncated. These tests exercise the
load-bearing SQL -- vector search, window-function scoring/leaderboards,
multi-table transactions -- that SQLite cannot execute, so they need real
Postgres.

Provisioning is dual-mode:

* If ``DATABASE_URL`` already points at an ``asyncpg`` Postgres (e.g. a CI
  service container), that instance is used as-is.
* Otherwise an ephemeral ``pgvector/pgvector`` container is started and torn
  down at session end. Override the image with ``FERMI_TEST_PG_IMAGE``.

If Docker is unavailable and no ``DATABASE_URL`` is set, local runs skip the
suite while CI fails closed so deployment gates cannot silently pass.
"""

import asyncio
import os
import shutil
import subprocess
from collections.abc import AsyncGenerator, Generator
from pathlib import Path

# Import models so SQLModel.metadata is fully populated before any DDL runs.
import fermi_db.models  # noqa: F401
import pytest
import pytest_asyncio
import sqlalchemy as sa
from alembic import command
from alembic.config import Config
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool
from sqlmodel.ext.asyncio.session import AsyncSession

# packages/fermi-db/tests/integration/ -> parents[4] is the repo root.
_REPO_ROOT = Path(__file__).resolve().parents[4]
_PG_IMAGE = os.environ.get('FERMI_TEST_PG_IMAGE', 'pgvector/pgvector:pg17')

# We stop the container explicitly (see ``database_url``), so the Ryuk reaper is
# an unnecessary extra image pull that can need elevated permissions in CI.
os.environ.setdefault('TESTCONTAINERS_RYUK_DISABLED', 'true')


async def _wait_until_ready(url: str, *, attempts: int = 40) -> None:
    """Ping Postgres over TCP until it accepts connections (or give up).

    Pinging over TCP (rather than trusting a log line) is robust against the
    Postgres image's two-phase startup: the init-phase server listens only on a
    unix socket, so a TCP connection cannot succeed until the real server is up.
    """
    last_exc: Exception | None = None
    for _ in range(attempts):
        engine = create_async_engine(url, poolclass=NullPool)
        try:
            async with engine.connect() as conn:
                await conn.execute(sa.text('SELECT 1'))
            return
        except Exception as exc:
            last_exc = exc
            await asyncio.sleep(0.5)
        finally:
            await engine.dispose()
    raise RuntimeError(f'Postgres did not become ready at {url}: {last_exc}')


def _ensure_docker_host() -> None:
    """Make the Docker daemon discoverable by the docker SDK / testcontainers.

    The docker CLI resolves the daemon via *contexts* (e.g. Docker Desktop's
    ``desktop-linux`` -> ``unix:///home/<user>/.docker/desktop/docker.sock``,
    or rootless Docker under ``$XDG_RUNTIME_DIR``), but the Python docker SDK
    only honours ``DOCKER_HOST`` or the default ``/var/run/docker.sock``. Bridge
    the two by exporting the active context's endpoint when neither is present.
    Best-effort: stays silent if anything is missing.
    """
    if os.environ.get('DOCKER_HOST'):
        return
    docker = shutil.which('docker')
    if not docker:
        return
    try:
        result = subprocess.run(  # noqa: S603
            [docker, 'context', 'inspect', '--format', '{{.Endpoints.docker.Host}}'],
            capture_output=True,
            text=True,
            timeout=10,
            check=True,
        )
    except Exception:
        return
    host = result.stdout.strip()
    if host:
        os.environ['DOCKER_HOST'] = host


@pytest.fixture(scope='session', autouse=True)
def database_url() -> Generator[str, None, None]:
    """Yield an asyncpg ``DATABASE_URL``, starting a pgvector container if needed."""
    existing = os.environ.get('DATABASE_URL')
    if existing and existing.startswith('postgresql+asyncpg://'):
        asyncio.run(_wait_until_ready(existing))
        yield existing
        return

    _ensure_docker_host()
    try:
        from testcontainers.core.container import DockerContainer
    except ImportError:  # pragma: no cover - dev dependency missing
        if os.environ.get('CI'):
            pytest.fail(
                'testcontainers is required for DB integration tests in CI',
                pytrace=False,
            )
        pytest.skip('testcontainers not installed and DATABASE_URL not set')

    try:
        container = (
            DockerContainer(_PG_IMAGE)
            .with_env('POSTGRES_USER', 'postgres')
            .with_env('POSTGRES_PASSWORD', 'postgres')
            .with_env('POSTGRES_DB', 'fermi-db')
            .with_exposed_ports(5432)
        )
        container.start()
    except Exception as exc:
        if os.environ.get('CI'):
            pytest.fail(
                f'Could not start required Postgres container in CI: {exc}',
                pytrace=False,
            )
        pytest.skip(f'Could not start Postgres container (is Docker running?): {exc}')

    try:
        host = container.get_container_host_ip()
        port = container.get_exposed_port(5432)
        url = f'postgresql+asyncpg://postgres:postgres@{host}:{port}/fermi-db'
        asyncio.run(_wait_until_ready(url))
        os.environ['DATABASE_URL'] = url
        yield url
    finally:
        container.stop()


@pytest.fixture(scope='session', autouse=True)
def _migrate(database_url: str) -> None:
    """Apply Alembic migrations to head once per session (builds the real schema).

    Uses Alembic's in-process API from the repo root. ``script_location`` in the
    root ``alembic.ini`` is relative to the repo root, so cwd is set there and the
    option is re-asserted. env.py reads ``DATABASE_URL`` from the environment; this
    fixture is sync, so env.py's ``asyncio.run`` has no running loop to clash with.
    """
    prev_cwd = Path.cwd()
    try:
        os.chdir(_REPO_ROOT)
        cfg = Config('alembic.ini')
        cfg.set_main_option('script_location', 'packages/fermi-db/alembic')
        command.upgrade(cfg, 'head')
    finally:
        os.chdir(prev_cwd)


@pytest.fixture(scope='session')
def engine(database_url: str) -> Generator[AsyncEngine, None, None]:
    """Session-scoped async engine.

    ``NullPool`` keeps every connection short-lived, which avoids handing an
    asyncpg connection created in one test's event loop to another (pytest-asyncio
    uses a fresh loop per test by default). This is what lets the engine be
    session-scoped instead of recreated per test.
    """
    eng = create_async_engine(database_url, echo=False, poolclass=NullPool)
    yield eng
    asyncio.run(eng.dispose())


async def _truncate_all(engine: AsyncEngine) -> None:
    """Truncate every application table.

    Reads ``pg_tables`` rather than ``SQLModel.metadata`` so it stays correct
    even if the ORM metadata and the migrated schema drift apart.
    """
    async with engine.begin() as conn:
        result = await conn.execute(
            sa.text(
                'SELECT tablename FROM pg_tables '
                "WHERE schemaname = 'public' AND tablename <> 'alembic_version'",
            ),
        )
        tables = [row[0] for row in result]
        if tables:
            names = ', '.join(f'"{t}"' for t in tables)
            await conn.execute(
                sa.text(f'TRUNCATE TABLE {names} RESTART IDENTITY CASCADE'),
            )


@pytest_asyncio.fixture
async def session(
    engine: AsyncEngine,
    _migrate: None,
) -> AsyncGenerator[AsyncSession, None]:
    """Yield a clean ``AsyncSession``; all tables are truncated before each test."""
    await _truncate_all(engine)
    maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with maker() as s:
        yield s
