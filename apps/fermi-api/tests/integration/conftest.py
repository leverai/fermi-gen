"""Integration test fixtures for API client and local emulators.

These fixtures assume Firestore and Firebase Auth emulators are running and
`apps/fermi-api/.env` is present.

Postgres is provisioned dual-mode by the ``database_url`` fixture (mirroring the
fermi-db harness):

* If ``DATABASE_URL`` already points at an ``asyncpg`` Postgres (e.g. a CI
  service container), that instance is used as-is.
* Otherwise an ephemeral ``pgvector/pgvector`` container is started via
  **testcontainers** and torn down at session end. Override the image with
  ``FERMI_TEST_PG_IMAGE``.

If Docker is unavailable and no ``DATABASE_URL`` is set, the integration suite is
**skipped** (not errored). Crucially the container is started and
``os.environ['DATABASE_URL']`` set BEFORE the app's ``fermi_db.session`` module
is first imported (which happens when ``api_client`` imports ``main``), because
``api_client`` and the seed/migrate fixtures depend on ``database_url``.
"""

import asyncio
import os
import shutil
import subprocess
from collections.abc import Callable, Generator
from pathlib import Path
from typing import Any

# Ensure models are registered with SQLModel.metadata. NOTE: importing
# ``fermi_db.models`` does NOT transitively import ``fermi_db.session`` (verified),
# so the global ``async_engine`` is NOT bound here; binding is deferred until
# ``api_client`` imports ``main`` -- by which point ``database_url`` has run.
import fermi_db.models  # noqa: F401
import httpx
import pytest
import sqlalchemy as sa
from dotenv import load_dotenv
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel import SQLModel

# apps/fermi-api/tests/integration/ -> parents[4] is the repo root.
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
    from sqlalchemy.pool import NullPool

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
    if os.environ.get('DOCKER_HOST') or Path('/var/run/docker.sock').exists():
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
    """Yield an asyncpg ``DATABASE_URL``, starting a pgvector container if needed.

    Autouse + session-scoped so the container is provisioned and
    ``os.environ['DATABASE_URL']`` set BEFORE any fixture that imports the app's
    ``fermi_db.session`` (the app binds its global engine to ``DATABASE_URL`` at
    import time). ``api_client`` / ``_migrate`` / ``_seed_questions_once`` all
    depend on this fixture so pytest orders them after it.
    """
    existing = os.environ.get('DATABASE_URL')
    if existing and existing.startswith('postgresql+asyncpg://'):
        asyncio.run(_wait_until_ready(existing))
        yield existing
        return

    _ensure_docker_host()
    try:
        from testcontainers.core.container import DockerContainer
    except ImportError:  # pragma: no cover - dev dependency missing
        pytest.skip('testcontainers not installed and DATABASE_URL not set')

    container = (
        DockerContainer(_PG_IMAGE)
        .with_env('POSTGRES_USER', 'postgres')
        .with_env('POSTGRES_PASSWORD', 'postgres')
        .with_env('POSTGRES_DB', 'fermi-db')
        .with_exposed_ports(5432)
    )
    try:
        container.start()
    except Exception as exc:
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
    from alembic import command
    from alembic.config import Config

    prev_cwd = Path.cwd()
    try:
        os.chdir(_REPO_ROOT)
        cfg = Config('alembic.ini')
        cfg.set_main_option('script_location', 'packages/fermi-db/alembic')
        command.upgrade(cfg, 'head')
    finally:
        os.chdir(prev_cwd)


@pytest.fixture(scope='session', autouse=True)
def _load_env(database_url: str) -> None:
    """Load `.env` under `apps/fermi-api` for integration tests.

    Depends on ``database_url`` so Postgres provisioning reads the *genuine*
    environment first. ``.env`` ships an app-default ``DATABASE_URL`` (the
    compose ``db`` on :5433); loading it before ``database_url`` would make the
    dual-mode fixture take the "external DB" branch and never start a
    testcontainer. Running after ``database_url`` means ``DATABASE_URL`` is
    already set to the provisioned DSN and ``override=False`` leaves it intact.
    """
    # apps/fermi-api/tests/integration/ -> parents[2] is apps/fermi-api
    env_path = Path(__file__).resolve().parents[2] / '.env'
    if env_path.exists():
        load_dotenv(env_path, override=False)


@pytest.fixture(scope='session', autouse=True)
def _verify_emulator_env_vars() -> None:
    """Assert required emulator env vars are set (no defaults allowed)."""
    assert os.environ.get('GOOGLE_CLOUD_PROJECT'), (
        'GOOGLE_CLOUD_PROJECT is not set. Use `make test-api-integration` '
        'or export GOOGLE_CLOUD_PROJECT=fermi-local'
    )
    assert os.environ.get('FIRESTORE_EMULATOR_HOST'), (
        'FIRESTORE_EMULATOR_HOST is not set. Use `make test-api-integration` '
        'or export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080'
    )
    assert os.environ.get('FIREBASE_AUTH_EMULATOR_HOST'), (
        'FIREBASE_AUTH_EMULATOR_HOST is not set. Use `make test-api-integration` '
        'or export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099'
    )


@pytest.fixture(scope='session', autouse=True)
def _verify_emulators_reachable() -> None:
    """Fail fast with a clear message if emulators are not reachable.

    Prevents hangs caused by missing headers or offline emulators by asserting
    the Firestore emulator responds to an authenticated request.
    """
    project = os.environ.get('GOOGLE_CLOUD_PROJECT')
    fs_host = os.environ.get('FIRESTORE_EMULATOR_HOST')
    assert project, (
        'GOOGLE_CLOUD_PROJECT is not set. Use `make test-api-integration` '
        'or export GOOGLE_CLOUD_PROJECT=fermi-local'
    )
    assert fs_host, (
        'FIRESTORE_EMULATOR_HOST is not set. Use `make test-api-integration` '
        'or export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080'
    )
    base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'
    try:
        r = httpx.get(
            f'{base}/games?pageSize=1',
            headers={
                'Authorization': 'Bearer owner',
                'X-Goog-User-Project': project,
            },
            timeout=2.0,
        )
    except Exception as exc:  # pragma: no cover - environment guard
        raise AssertionError(
            'Firestore emulator is not reachable. Use `make test-api-integration` '
            'or set FIRESTORE_EMULATOR_HOST/GOOGLE_CLOUD_PROJECT and start emulators.',
        ) from exc

    assert r.status_code in (200, 404), (
        'Firestore emulator did not respond as expected (need auth headers?). '
        'Use `make test-api-integration` to run tests with emulators.'
    )


@pytest.fixture(scope='session')
def api_client(database_url: str, _migrate: None) -> Generator[TestClient, None, None]:
    """Provide real app `TestClient` with lifespan enabled.

    Depends on ``database_url`` (and ``_migrate``) so the testcontainers Postgres
    is up and ``DATABASE_URL`` is set BEFORE this fixture imports ``main`` (which
    imports ``fermi_db.session`` and binds the global engine to ``DATABASE_URL``).

    Ensures CWD is `apps/fermi-api` so StaticFiles('static') resolves.
    """
    # Ensure CWD is apps/fermi-api so StaticFiles('static') exists
    prev = Path.cwd()
    try:
        os.chdir(Path(__file__).resolve().parents[2])
        import importlib

        main = importlib.import_module('main')
        with TestClient(main.app) as c:
            yield c
    finally:
        os.chdir(prev)


def _auth_emulator_base_url() -> str:
    """Return base URL for the Firebase Auth emulator."""
    host = os.environ.get('FIREBASE_AUTH_EMULATOR_HOST')
    assert host, (
        'FIREBASE_AUTH_EMULATOR_HOST is not set. Use `make test-api-integration` '
        'or export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099'
    )
    return f'http://{host}'


@pytest.fixture
def create_emulator_user_and_get_token() -> Callable[[str, str, str], dict[str, Any]]:
    """Return factory to create a user and retrieve emulator tokens.

    The returned callable signature is `(email, password, display_name) -> dict` and
    includes `idToken` and `localId`.
    """
    base = _auth_emulator_base_url()

    def _create(email: str, password: str, display_name: str) -> dict[str, Any]:
        # Strict sign up; tests should ensure clean emulator state per run
        resp = httpx.post(
            f'{base}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
            json={
                'email': email,
                'password': password,
                'displayName': display_name,
                'returnSecureToken': True,
            },
            timeout=10.0,
        )
        resp.raise_for_status()
        # Then sign in to get tokens
        resp2 = httpx.post(
            f'{base}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
            json={'email': email, 'password': password, 'returnSecureToken': True},
            timeout=10.0,
        )
        resp2.raise_for_status()
        return resp2.json()

    return _create


@pytest.fixture
def reset_emulators() -> Callable[[], None]:
    """Return a function that clears Auth users and Firestore `games` docs."""
    project = os.environ['GOOGLE_CLOUD_PROJECT']
    fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
    auth_base = _auth_emulator_base_url()

    def _clear() -> None:
        # Clear auth users (best-effort)
        try:
            httpx.delete(
                f'{auth_base}/emulator/v1/projects/{project}/accounts',
                timeout=5.0,
            )
        except Exception as exc:  # logging-only best-effort cleanup
            import logging

            logging.getLogger(__name__).debug('Auth emulator reset failed: %s', exc)

        # Clear Firestore games collection (best-effort, shallow + known subcollections)
        base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'
        try:
            r = httpx.get(f'{base}/games?pageSize=1000', timeout=5.0)
            if r.status_code == 200 and 'documents' in r.json():
                for doc in r.json().get('documents', []):
                    name = doc['name']  # full resource path ends with /games/{id}
                    game_id = name.split('/')[-1]
                    # delete known subcollections
                    for sub in ('questions', 'answers', 'players_results'):
                        sr = httpx.get(
                            f'{base}/games/{game_id}/{sub}?pageSize=1000',
                            timeout=5.0,
                        )
                        if sr.status_code == 200:
                            for sdoc in (
                                sr.json().get('documents', [])
                                if isinstance(sr.json(), dict)
                                else []
                            ):
                                sname = sdoc['name']
                                tail = sname.split('/')[-1]
                                httpx.delete(
                                    f'{base}/games/{game_id}/{sub}/{tail}',
                                    timeout=5.0,
                                )
                    httpx.delete(f'{base}/games/{game_id}', timeout=5.0)
        except Exception as exc:  # logging-only best-effort cleanup
            import logging

            logging.getLogger(__name__).debug(
                'Firestore emulator reset failed: %s',
                exc,
            )

    return _clear


@pytest.fixture(autouse=True)
def _reset_emulators_before_each_test(reset_emulators: Callable[[], None]) -> None:
    """Reset emulators before each test for deterministic isolation."""
    reset_emulators()


"""--- Database reset per test ---"""


async def _truncate_all_tables_async() -> None:
    """Truncate all application tables to ensure DB isolation per test.

    Uses TRUNCATE ... RESTART IDENTITY CASCADE on PostgreSQL, otherwise falls back
    to DELETE for each table (e.g., SQLite in local runs).
    """
    # Exclude Alembic version table, seed data tables, and fermi MV from truncation
    # fermi is a materialized view but appears in metadata due to SQLModel definition
    tables = [
        t
        for t in SQLModel.metadata.sorted_tables
        if t.name
        not in ('alembic_version', 'seeds', 'fermi_questions', 'fermi_answers', 'fermi')
    ]
    if not tables:
        return

    # Create a short-lived engine bound to the current event loop
    db_url = os.environ.get('DATABASE_URL', 'sqlite+aiosqlite:///./guesstimate.db')
    engine = create_async_engine(db_url, echo=False)
    async with engine.begin() as conn:
        dialect = conn.dialect.name
        if dialect in ('postgresql', 'postgres'):
            table_names = ', '.join(f'"{t.name}"' for t in tables)
            await conn.execute(
                sa.text(f'TRUNCATE TABLE {table_names} RESTART IDENTITY CASCADE'),
            )
        else:
            for t in tables:
                await conn.execute(t.delete())
    await engine.dispose()


def _truncate_all_tables_sync() -> None:
    # Run the async truncation in a fresh event loop; tests are sync.
    asyncio.run(_truncate_all_tables_async())


@pytest.fixture(autouse=True)
def _reset_db_before_each_test(database_url: str) -> None:
    """Reset the database state between tests (tables truncated).

    Depends on ``database_url`` so truncation runs against the provisioned
    container DSN (seed tables are excluded by ``_truncate_all_tables_async``).
    """
    _truncate_all_tables_sync()


@pytest.fixture(scope='session', autouse=True)
def _seed_questions_once(database_url: str, _migrate: None) -> None:
    """Seed minimal questions into Postgres once per test session.

    Seeds the new schema: seeds → fermi_questions → fermi_answers → fermi MV.
    Uses subprocess to avoid event loop conflicts with test isolation.
    Depends on ``database_url`` (container up + ``DATABASE_URL`` set) and
    ``_migrate`` (schema applied) so seeding runs after both.
    """
    import shutil
    import subprocess

    dsn = os.environ.get('DATABASE_URL')
    assert dsn, 'DATABASE_URL is not set'

    uv_exe = shutil.which('uv') or 'uv'
    test_data_path = (
        Path(__file__).resolve().parents[1] / 'data' / 'test_questions.json'
    )

    assert test_data_path.exists(), 'Test data not found'

    subprocess.run(  # noqa: S603
        [
            uv_exe,
            'run',
            '--package',
            'fermi-db',
            'scripts/seed_test_questions.py',
            '--file',
            str(test_data_path),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


@pytest.fixture
def get_api_auth_headers(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict[str, Any]],
) -> Callable[[str, str, str], dict[str, str]]:
    """Return a factory that exchanges emulator token for API access token headers."""

    def _make(email: str, password: str, display_name: str) -> dict[str, str]:
        token_info = create_emulator_user_and_get_token(email, password, display_name)
        firebase_token = token_info['idToken']
        resp = api_client.post(
            '/api/v1/auth/token',
            headers={'Authorization': f'Bearer {firebase_token}'},
        )
        resp.raise_for_status()
        access_token = resp.json()['access_token']
        return {'Authorization': f'Bearer {access_token}'}

    return _make


@pytest.fixture
def get_pro_api_auth_headers(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict[str, Any]],
) -> Callable[[str, str, str], dict[str, str]]:
    """Return a factory that creates a Pro user and returns API access token headers.

    The user is created with an active Pro subscription in the database.
    Use this for testing tier-gated endpoints like post-take.
    """
    import asyncio

    from fermi_db.models.subscription import SubscriptionPlatform, SubscriptionTier
    from fermi_db.repositories.subscription_repository import SubscriptionRepository
    from fermi_db.repositories.user_repository import UserRepository
    from sqlmodel.ext.asyncio.session import AsyncSession

    def _make(email: str, password: str, display_name: str) -> dict[str, str]:
        # First create normal user and get headers
        token_info = create_emulator_user_and_get_token(email, password, display_name)
        firebase_token = token_info['idToken']
        firebase_uid = token_info['localId']
        resp = api_client.post(
            '/api/v1/auth/token',
            headers={'Authorization': f'Bearer {firebase_token}'},
        )
        resp.raise_for_status()
        access_token = resp.json()['access_token']

        # Now add Pro subscription directly to DB
        # Create a fresh engine to avoid event loop conflicts
        async def _add_subscription() -> None:
            db_url = os.environ.get(
                'DATABASE_URL',
                'sqlite+aiosqlite:///./guesstimate.db',
            )
            engine = create_async_engine(db_url, echo=False)
            async with AsyncSession(engine) as session:
                user_repo = UserRepository(session)
                sub_repo = SubscriptionRepository(session)
                user = await user_repo.get_by_firebase_uid(firebase_uid)
                if user and user.id:
                    await sub_repo.upsert_subscription(
                        user_id=user.id,
                        revenuecat_user_id=firebase_uid,
                        tier=SubscriptionTier.PRO,
                        product_id='test_pro_subscription',
                        platform=SubscriptionPlatform.PROMOTIONAL,
                        is_active=True,
                    )
                await session.commit()
            await engine.dispose()

        asyncio.run(_add_subscription())
        return {'Authorization': f'Bearer {access_token}'}

    return _make


def _decode_firestore_value(node: Any) -> Any:
    """Recursively decode a Firestore REST ``Value`` into a plain Python value."""
    if isinstance(node, dict):
        if 'mapValue' in node:
            fields = node['mapValue'].get('fields', {})
            return {k: _decode_firestore_value(v) for k, v in fields.items()}
        if 'arrayValue' in node:
            vals = node['arrayValue'].get('values', [])
            return [_decode_firestore_value(v) for v in vals]
        if 'integerValue' in node:
            try:
                return int(node['integerValue'])
            except Exception:
                return node['integerValue']
        if 'doubleValue' in node:
            try:
                return float(node['doubleValue'])
            except Exception:
                return node['doubleValue']
        for k in (
            'stringValue',
            'booleanValue',
            'nullValue',
            'timestampValue',
        ):
            if k in node:
                return node[k]
        return {k: _decode_firestore_value(v) for k, v in node.items()}
    return node


def _poll_firestore_doc(doc_path: str) -> dict[str, Any]:
    """GET a Firestore document by path, polling ~5s for eventual consistency.

    ``doc_path`` is relative to the documents base (e.g. ``games/{id}`` or
    ``games/{id}/answers/{uid}``). Returns the decoded ``fields`` map (with the
    raw response as a fallback when no ``fields`` key is present), or ``{}`` if
    the document never appears.
    """
    import time

    project = os.environ['GOOGLE_CLOUD_PROJECT']
    fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
    base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

    for _ in range(50):
        r = httpx.get(
            f'{base}/{doc_path}',
            headers={
                'Authorization': 'Bearer owner',
                'X-Goog-User-Project': project,
            },
            timeout=2.0,
        )
        if r.status_code == 200:
            data = r.json()
            if 'fields' in data:
                return {
                    k: _decode_firestore_value(v) for k, v in data['fields'].items()
                }
            return data
        time.sleep(0.1)
    return {}


@pytest.fixture
def get_firestore_doc() -> Callable[[str], dict[str, Any]]:
    """Return a callable that fetches a game document via emulator REST API.

    Usage: ``doc = get_firestore_doc(game_id)``
    """

    def _get(game_id: str) -> dict[str, Any]:
        # Poll up to ~5s for eventual consistency
        import time

        project = os.environ['GOOGLE_CLOUD_PROJECT']
        fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
        base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

        for _ in range(50):
            r = httpx.get(
                f'{base}/games/{game_id}',
                headers={
                    'Authorization': 'Bearer owner',
                    'X-Goog-User-Project': project,
                },
                timeout=2.0,
            )
            if r.status_code == 200:
                data = r.json()
                if 'fields' in data:
                    plain: dict[str, Any] = {
                        k: _decode_firestore_value(v) for k, v in data['fields'].items()
                    }
                    if 'name' in data and isinstance(data['name'], str):
                        plain['id'] = data['name'].split('/')[-1]
                    return plain
                return data
            time.sleep(0.1)
        return {}

    return _get


@pytest.fixture
def list_firestore_subcollection_docs() -> Callable[[str, str], list[str]]:
    """Return a callable that lists document IDs in a game's subcollection.

    Usage: ``ids = list_firestore_subcollection_docs(game_id, 'questions')``
    Supported subcollections: ``questions``, ``answers``, ``players_results``.
    """

    def _list(game_id: str, subcollection: str) -> list[str]:
        if subcollection not in {'questions', 'answers', 'players_results'}:
            raise ValueError('invalid subcollection name')

        project = os.environ['GOOGLE_CLOUD_PROJECT']
        fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
        base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

        try:
            r = httpx.get(
                f'{base}/games/{game_id}/{subcollection}?pageSize=1000',
                headers={
                    'Authorization': 'Bearer owner',
                    'X-Goog-User-Project': project,
                },
                timeout=3.0,
            )
            if r.status_code != 200:
                return []
            body = r.json()
            docs = body.get('documents', []) if isinstance(body, dict) else []
            ids: list[str] = []
            for doc in docs:
                if not isinstance(doc, dict):
                    continue
                full_name = doc.get('name', '')
                if isinstance(full_name, str) and full_name:
                    ids.append(full_name.split('/')[-1])
            return ids
        except Exception:
            return []

    return _list


@pytest.fixture
def get_players_results_doc() -> Callable[[str, str], dict[str, Any]]:
    """Return a callable that fetches a players_results document by question_uid.

    Usage: ``doc = get_players_results_doc(game_id, question_uid)``
    """

    def _get(game_id: str, question_uid: str) -> dict[str, Any]:
        return _poll_firestore_doc(f'games/{game_id}/players_results/{question_uid}')

    return _get


@pytest.fixture
def get_answer_doc() -> Callable[[str, str], dict[str, Any]]:
    """Return a callable that fetches an answer document by question_uid.

    Usage: ``doc = get_answer_doc(game_id, question_uid)``
    """

    def _get(game_id: str, question_uid: str) -> dict[str, Any]:
        return _poll_firestore_doc(f'games/{game_id}/answers/{question_uid}')

    return _get


@pytest.fixture
def create_private_game(api_client: TestClient) -> Callable[[dict[str, str]], str]:
    """Return a callable that creates a private game and returns its id.

    The callable signature is ``(headers) -> game_id``. Optional kwargs may be
    supplied for ``n_questions``, ``categories``, and ``difficulty``.
    """

    def _create(
        headers: dict[str, str],
        *,
        n_questions: int = 3,
        categories: list[str] | None = None,
        difficulty: str | None = None,
    ) -> str:
        payload = {
            'question_round_settings': {
                'n_questions': n_questions,
                'categories': categories,
                'difficulty': difficulty,
            },
        }
        resp = api_client.post('/api/v1/game/create', json=payload, headers=headers)
        resp.raise_for_status()
        return resp.json()['resource_id']

    return _create


@pytest.fixture(scope='session', autouse=True)
def _dispose_engine_at_end() -> Generator[None, None, None]:
    yield
    from fermi_db.session import async_engine

    asyncio.run(async_engine.dispose())
