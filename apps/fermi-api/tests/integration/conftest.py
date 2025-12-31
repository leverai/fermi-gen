"""Integration test fixtures for API client and local emulators.

These fixtures assume Firestore and Firebase Auth emulators are running and
`apps/fermi-api/.env` is present. The DB schema is applied once per
session when `DATABASE_URL` is set.
"""

import asyncio
import os
from collections.abc import Callable, Generator
from pathlib import Path
from typing import Any

# Ensure models are registered with SQLModel.metadata
import fermi_db.models  # noqa: F401
import httpx
import pytest
import sqlalchemy as sa
from dotenv import load_dotenv
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine
from sqlmodel import SQLModel


@pytest.fixture(scope='session', autouse=True)
def _load_env() -> None:
    """Load `.env` under `apps/fermi-api` for integration tests."""
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


@pytest.fixture(scope='session', autouse=True)
def _verify_database_reachable() -> None:
    """Fail fast if DATABASE_URL is missing or DB is unreachable.

    Ensures integration tests run against Postgres via asyncpg rather than
    silently falling back to SQLite, which can cause background tasks to no-op.
    """
    db_url = os.environ.get('DATABASE_URL')
    assert db_url, (
        'DATABASE_URL is not set. Use `make test-api-integration` or export\n'
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


@pytest.fixture(scope='session')
def api_client() -> Generator[TestClient, None, None]:
    """Provide real app `TestClient` with lifespan enabled.

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
def _reset_db_before_each_test() -> None:
    """Reset the database state between tests (tables truncated)."""
    _truncate_all_tables_sync()


@pytest.fixture(scope='session', autouse=True)
def _seed_questions_once() -> None:
    """Seed minimal questions into Postgres once per test session.

    Seeds the new schema: seeds → fermi_questions → fermi_answers → fermi MV.
    Uses subprocess to avoid event loop conflicts with test isolation.
    Relies on DATABASE_URL being set by the test harness.
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
def get_firestore_doc() -> Callable[[str], dict[str, Any]]:
    """Return a callable that fetches a game document via emulator REST API.

    Usage: ``doc = get_firestore_doc(game_id)``
    """

    def _get(game_id: str) -> dict[str, Any]:
        project = os.environ['GOOGLE_CLOUD_PROJECT']
        fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
        base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

        def _convert(node: Any) -> Any:
            if isinstance(node, dict):
                if 'mapValue' in node:
                    fields = node['mapValue'].get('fields', {})
                    return {k: _convert(v) for k, v in fields.items()}
                if 'arrayValue' in node:
                    vals = node['arrayValue'].get('values', [])
                    return [_convert(v) for v in vals]
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
                return {k: _convert(v) for k, v in node.items()}
            return node

        # Poll up to ~5s for eventual consistency
        import time

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
                    fields = data['fields']
                    plain: dict[str, Any] = {k: _convert(v) for k, v in fields.items()}
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
        project = os.environ['GOOGLE_CLOUD_PROJECT']
        fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
        base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

        def _convert(node: Any) -> Any:
            if isinstance(node, dict):
                if 'mapValue' in node:
                    fields = node['mapValue'].get('fields', {})
                    return {k: _convert(v) for k, v in fields.items()}
                if 'arrayValue' in node:
                    vals = node['arrayValue'].get('values', [])
                    return [_convert(v) for v in vals]
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
                return {k: _convert(v) for k, v in node.items()}
            return node

        # Poll up to ~5s for eventual consistency
        import time

        for _ in range(50):
            r = httpx.get(
                f'{base}/games/{game_id}/players_results/{question_uid}',
                headers={
                    'Authorization': 'Bearer owner',
                    'X-Goog-User-Project': project,
                },
                timeout=2.0,
            )
            if r.status_code == 200:
                data = r.json()
                if 'fields' in data:
                    fields = data['fields']
                    return {k: _convert(v) for k, v in fields.items()}
                return data
            time.sleep(0.1)
        return {}

    return _get


@pytest.fixture
def get_answer_doc() -> Callable[[str, str], dict[str, Any]]:
    """Return a callable that fetches an answer document by question_uid.

    Usage: ``doc = get_answer_doc(game_id, question_uid)``
    """

    def _get(game_id: str, question_uid: str) -> dict[str, Any]:
        project = os.environ['GOOGLE_CLOUD_PROJECT']
        fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
        base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

        def _convert(node: Any) -> Any:
            if isinstance(node, dict):
                if 'mapValue' in node:
                    fields = node['mapValue'].get('fields', {})
                    return {k: _convert(v) for k, v in fields.items()}
                if 'arrayValue' in node:
                    vals = node['arrayValue'].get('values', [])
                    return [_convert(v) for v in vals]
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
                return {k: _convert(v) for k, v in node.items()}
            return node

        # Poll up to ~5s for eventual consistency
        import time

        for _ in range(50):
            r = httpx.get(
                f'{base}/games/{game_id}/answers/{question_uid}',
                headers={
                    'Authorization': 'Bearer owner',
                    'X-Goog-User-Project': project,
                },
                timeout=2.0,
            )
            if r.status_code == 200:
                data = r.json()
                if 'fields' in data:
                    fields = data['fields']
                    return {k: _convert(v) for k, v in fields.items()}
                return data
            time.sleep(0.1)
        return {}

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


@pytest.fixture
def mark_questions_seen_for_user() -> Callable[[str, list[str]], None]:
    """Return a callable that marks questions as seen for a user in the DB.

    Executes a small uv-run script to avoid event-loop conflicts inside tests.
    """
    import shutil
    import subprocess

    uv_exe = shutil.which('uv') or 'uv'

    def _mark(user_id: str, question_uid_strs: list[str]) -> None:
        if not question_uid_strs:
            return
        # Resolve script path relative to this file
        # apps/fermi-api/tests/integration/conftest.py ->
        # ../../../../scripts/mark_seen.py
        script_path = Path(__file__).resolve().parents[4] / 'scripts' / 'mark_seen.py'
        cmd = [
            uv_exe,
            'run',
            '--package',
            'fermi-db',
            'python',
            str(script_path),
            '--user',
            user_id,
        ]
        for q in question_uid_strs:
            cmd += ['--question', q]
        subprocess.run(  # noqa: S603
            cmd,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    return _mark
