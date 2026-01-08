"""Unit tests for AuthService."""

# ruff: noqa: D103
from __future__ import annotations

from datetime import UTC
from types import SimpleNamespace
from typing import Any, cast

import pytest
from jose import jwt

from app.services.auth import AuthService, _get_emulator_claims
from app.services.errors import InvalidFirebaseTokenError, TokenTooOldError


class _FakeUserRepo:
    def __init__(self) -> None:
        self.user = SimpleNamespace(id='u-db', firebase_uid='u1')  # type: ignore[attr-defined]
        self.updated_from_claims: dict[str, Any] | None = None
        self.created_from_claims: dict[str, Any] | None = None

    async def get_by_firebase_uid(self, _uid: str) -> Any:
        return None

    async def login_user(self, user: Any, claims: dict[str, Any]) -> Any:
        self.updated_from_claims = claims
        return user

    async def register_user(self, claims: dict[str, Any]) -> Any:
        self.created_from_claims = claims
        return self.user


class _FakeSession:
    def __init__(self, user_repo: _FakeUserRepo) -> None:
        self._repo = user_repo


@pytest.mark.asyncio
async def test_get_emulator_claims_success(monkeypatch: pytest.MonkeyPatch) -> None:
    async def _fake_post(url: str, headers: dict[str, str], content: str) -> Any:
        class _Resp:
            status_code = 200

            def json(self) -> dict[str, Any]:
                return {
                    'users': [
                        {
                            'localId': 'u1',
                            'email': 'e',
                            'displayName': 'n',
                            'photoUrl': 'p',
                        },
                    ],
                }

        return _Resp()

    class _Client:
        def __init__(self, timeout: int) -> None:
            pass

        async def __aenter__(self) -> Any:
            return self

        async def __aexit__(
            self,
            exc_type: type[BaseException] | None,
            exc: BaseException | None,
            tb: Any | None,
        ) -> None:
            return None

        async def post(self, *args: Any, **kwargs: Any) -> Any:
            return await _fake_post(*args, **kwargs)

    # Patch httpx.AsyncClient in module scope
    import app.services.auth as auth_mod

    monkeypatch.setattr(auth_mod.httpx, 'AsyncClient', _Client)
    claims = await _get_emulator_claims('tok', '127.0.0.1:9099')
    assert claims['uid'] == 'u1'
    assert claims['email'] == 'e'


@pytest.mark.asyncio
async def test_get_emulator_claims_invalid_raises(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class _Resp:
        status_code = 401

        def json(self) -> dict[str, Any]:
            return {}

    class _Client:
        def __init__(self, timeout: int) -> None:
            pass

        async def __aenter__(self) -> Any:
            return self

        async def __aexit__(
            self,
            exc_type: type[BaseException] | None,
            exc: BaseException | None,
            tb: Any | None,
        ) -> None:
            return None

        async def post(self, *args: Any, **kwargs: Any) -> _Resp:
            return _Resp()

    import app.services.auth as auth_mod

    monkeypatch.setattr(auth_mod.httpx, 'AsyncClient', _Client)
    with pytest.raises(InvalidFirebaseTokenError):
        await _get_emulator_claims('tok', '127.0.0.1:9099')


@pytest.mark.asyncio
async def test_authenticate_user_emulator_path_creates_user_and_returns_token(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Ensure emulator path
    monkeypatch.setenv('USE_EMULATORS', 'true')

    # Stub emulator claims (async to match awaited function)
    async def _fake_get_claims(token: str, host: str) -> dict[str, Any]:
        return {'uid': 'u1', 'email': 'e', 'name': 'n', 'picture': 'p'}

    monkeypatch.setattr('app.services.auth._get_emulator_claims', _fake_get_claims)

    # Stub repo creation
    fake_repo = _FakeUserRepo()

    async def _fake_get_or_create(
        request: Any,
        session: Any,
        claims: dict[str, Any],
    ) -> Any:
        return await fake_repo.register_user(claims)

    svc = AuthService()
    monkeypatch.setattr(svc, '_get_or_create_user', _fake_get_or_create)

    # Create a fake request object
    fake_request = SimpleNamespace()

    result = await svc.authenticate_user(
        cast(Any, fake_request),
        cast(Any, _FakeSession(fake_repo)),
        'tok',
    )
    assert result is not None
    user, token = result
    assert user.id == 'u-db'
    assert token.token_type.lower() == 'bearer'

    # Decode token to verify claims contain user_id and exp
    decoded = jwt.get_unverified_claims(token.access_token)
    assert decoded['user_id'] == 'u-db'
    assert 'exp' in decoded


@pytest.mark.asyncio
async def test_authenticate_user_invalid_non_emulator_raises(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Force non-emulator path
    monkeypatch.delenv('USE_EMULATORS', raising=False)
    monkeypatch.delenv('FIREBASE_AUTH_EMULATOR_HOST', raising=False)

    # Stub firebase_admin.auth.verify_id_token to raise
    import firebase_admin

    # Import kept narrow for patching site; do not use directly
    from firebase_admin import auth as fb_auth

    if not firebase_admin._apps:
        firebase_admin.initialize_app()

    def _raise(*args: Any, **kwargs: Any) -> None:
        raise fb_auth.InvalidIdTokenError('bad')

    import app.services.auth as auth_mod

    monkeypatch.setattr(auth_mod.auth, 'verify_id_token', _raise)

    svc = AuthService()
    fake_request = SimpleNamespace()
    with pytest.raises(InvalidFirebaseTokenError):
        await svc.authenticate_user(
            cast(Any, fake_request),
            cast(Any, _FakeSession(_FakeUserRepo())),
            'tok',
        )


@pytest.mark.asyncio
async def test_authenticate_user_non_emulator_success(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Force non-emulator path
    monkeypatch.delenv('USE_EMULATORS', raising=False)
    monkeypatch.delenv('FIREBASE_AUTH_EMULATOR_HOST', raising=False)

    import firebase_admin

    if not firebase_admin._apps:
        firebase_admin.initialize_app()

    def _ok(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            'uid': 'u1',
            'email': 'e',
            'name': 'n',
            'picture': 'p',
        }

    import app.services.auth as auth_mod

    monkeypatch.setattr(auth_mod.auth, 'verify_id_token', _ok)

    # Stub _get_or_create_user to return a user object with id
    fake_user = SimpleNamespace(id='u-db')
    svc = AuthService()

    async def _fake_gocu(
        request: Any,
        session: Any,
        claims: dict[str, Any],
    ) -> Any:
        return fake_user

    monkeypatch.setattr(svc, '_get_or_create_user', _fake_gocu)

    fake_request = SimpleNamespace()
    result = await svc.authenticate_user(
        cast(Any, fake_request),
        cast(Any, _FakeSession(_FakeUserRepo())),
        'tok',
    )
    assert result is not None
    user, token = result
    assert user.id == 'u-db'
    decoded = jwt.get_unverified_claims(token.access_token)
    assert decoded['user_id'] == 'u-db'
    assert 'exp' in decoded
    assert 'iat' in decoded  # Verify iat claim is included


@pytest.mark.asyncio
async def test_refresh_access_token_with_valid_age_succeeds(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Test that tokens within the max refresh age can be refreshed."""
    from datetime import datetime, timedelta

    from app.core.config import settings

    # Create a token that's 10 days old (within 30 day limit)
    fake_user = SimpleNamespace(id=1)
    fake_repo = _FakeUserRepo()
    fake_repo.user = fake_user

    async def _fake_get_by_id(user_id: int) -> Any:
        return fake_user

    class _FakeUserRepoWithGetById:
        async def get_by_id(self, user_id: int) -> Any:
            return await _fake_get_by_id(user_id)

    fake_session = _FakeSession(_FakeUserRepoWithGetById())  # pyright: ignore[reportArgumentType]

    # Create a token with iat claim 10 days ago
    ten_days_ago = datetime.now(UTC) - timedelta(days=10)
    token_payload = {
        'user_id': 1,
        'iat': ten_days_ago,
        'exp': datetime.now(UTC) + timedelta(minutes=30),
    }
    old_token = jwt.encode(
        token_payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )

    svc = AuthService()
    monkeypatch.setattr(
        'app.services.auth.UserRepository',
        lambda _: _FakeUserRepoWithGetById(),
    )

    # Should succeed - token is within max refresh age
    user, new_token = await svc.refresh_access_token(
        cast(Any, fake_session),
        old_token,
    )
    assert user.id == 1
    assert new_token.access_token != old_token


@pytest.mark.asyncio
async def test_refresh_access_token_too_old_raises(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Test that tokens older than max refresh age are rejected."""
    from datetime import datetime, timedelta

    from app.core.config import settings

    # Create a token that's 31 days old (exceeds 30 day limit)
    fake_user = SimpleNamespace(id=1)

    class _FakeUserRepoWithGetById:
        async def get_by_id(self, user_id: int) -> Any:
            return fake_user

    fake_session = _FakeSession(_FakeUserRepoWithGetById())  # pyright: ignore[reportArgumentType]

    # Create a token with iat claim 31 days ago
    thirty_one_days_ago = datetime.now(UTC) - timedelta(days=31)
    token_payload = {
        'user_id': 1,
        'iat': thirty_one_days_ago,
        'exp': datetime.now(UTC) + timedelta(minutes=30),
    }
    old_token = jwt.encode(
        token_payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )

    svc = AuthService()
    monkeypatch.setattr(
        'app.services.auth.UserRepository',
        lambda _: _FakeUserRepoWithGetById(),
    )

    # Should raise TokenTooOldError
    with pytest.raises(TokenTooOldError):
        await svc.refresh_access_token(
            cast(Any, fake_session),
            old_token,
        )


@pytest.mark.asyncio
async def test_refresh_access_token_without_iat_allowed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Test that tokens without iat claim are allowed for backward compatibility."""
    from datetime import datetime, timedelta

    from app.core.config import settings

    fake_user = SimpleNamespace(id=1)

    class _FakeUserRepoWithGetById:
        async def get_by_id(self, user_id: int) -> Any:
            return fake_user

    fake_session = _FakeSession(_FakeUserRepoWithGetById())  # pyright: ignore[reportArgumentType]

    # Create a token without iat claim (old format)
    token_payload = {
        'user_id': 1,
        'exp': datetime.now(UTC) + timedelta(minutes=30),
    }
    old_token = jwt.encode(
        token_payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )

    svc = AuthService()
    monkeypatch.setattr(
        'app.services.auth.UserRepository',
        lambda _: _FakeUserRepoWithGetById(),
    )

    # Should succeed - backward compatibility for tokens without iat
    user, new_token = await svc.refresh_access_token(
        cast(Any, fake_session),
        old_token,
    )
    assert user.id == 1
    assert new_token.access_token != old_token
