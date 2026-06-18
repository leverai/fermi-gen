"""API-only fixtures for lightweight route tests (no lifespan/DB)."""

from collections.abc import Generator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.api import api_router
from app.api.v1.auth_deps import get_authenticated_user, get_current_user
from app.api.v1.authenticated_user import AuthenticatedUser
from app.api.v1.dependencies import get_firestore_client, get_game_service
from app.core.config import settings
from app.version import __version__


def create_test_app() -> FastAPI:
    """Create a FastAPI app mounting only the API router for tests."""
    app = FastAPI(
        title=settings.project_name,
        version=__version__,
        openapi_url=f'{settings.api_v1_str}/openapi.json',
    )
    app.include_router(api_router, prefix=settings.api_v1_str)
    return app


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """Yield a `TestClient` for the lightweight test app."""
    app = create_test_app()
    with TestClient(app) as c:
        yield c


@pytest.fixture
def client_overrides() -> Generator[TestClient, None, None]:
    """Yield a `TestClient` with overrides to avoid heavy deps (DB/emulator)."""
    app = create_test_app()

    class _DummyUser:
        def __init__(self) -> None:
            self.firebase_uid = 'dummy-uid'
            self.email = 'dummy@example.com'
            self.display_name = 'Dummy'
            self.picture = None

    def _dummy_authenticated_user() -> AuthenticatedUser:
        from fermi_db.models.user import User

        return AuthenticatedUser(
            user=User(
                id=1,
                firebase_uid='dummy-uid',
                email='dummy@example.com',
                display_name='Dummy',
            ),
        )

    async def _dummy_firestore() -> object:  # pragma: no cover
        class _Dummy:
            pass

        return _Dummy()

    class _DummyService:  # pragma: no cover
        pass

    app.dependency_overrides[get_current_user] = lambda: _DummyUser()
    app.dependency_overrides[get_authenticated_user] = _dummy_authenticated_user
    app.dependency_overrides[get_firestore_client] = _dummy_firestore
    app.dependency_overrides[get_game_service] = lambda: _DummyService()  # type: ignore[return-value]

    with TestClient(app) as c:
        yield c
