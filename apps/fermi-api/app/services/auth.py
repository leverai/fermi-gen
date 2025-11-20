"""Authentication service."""

import json
import os
from datetime import timedelta
from typing import TYPE_CHECKING, Any
from urllib.parse import urlencode

import firebase_admin
import httpx
from fastapi import Request
from fermi_core import utcnow_naive
from fermi_db.models.user import User
from fermi_db.repositories.user_repository import UserRepository
from firebase_admin import auth
from jose import jwt
from sqlmodel.ext.asyncio.session import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import settings
from app.schemas.auth import Token
from app.services.errors import InvalidFirebaseTokenError
from app.services.utils import (
    enrich_firebase_claims,
)

if TYPE_CHECKING:
    from fastapi import Response


async def _get_emulator_claims(
    firebase_token: str,
    emulator_host: str,
) -> dict[str, Any]:
    """Get claims from the Auth emulator."""
    base = f'http://{emulator_host}'
    url = f'{base}/identitytoolkit.googleapis.com/v1/accounts:lookup?' + urlencode(
        {'key': 'fake-api-key'},
    )
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            url,
            headers={'Content-Type': 'application/json'},
            content=json.dumps({'idToken': firebase_token}),
        )
    if resp.status_code != 200:
        raise InvalidFirebaseTokenError
    info = resp.json()
    users = info.get('users') or []
    if not users:
        raise InvalidFirebaseTokenError
    u0 = users[0]
    firebase_claims = {
        'uid': u0.get('localId'),
        'email': u0.get('email'),
        'name': u0.get('displayName'),
        'picture': u0.get('photoUrl'),
    }
    return firebase_claims


class AuthService:
    """Service for authentication-related operations."""

    def __init__(self):
        """Initialize the service."""
        if not firebase_admin._apps:
            firebase_admin.initialize_app()

    async def _create_access_token(
        self,
        to_encode: dict[str, Any],
        expires_delta: timedelta | None = None,
    ) -> str:
        """Create an access token."""
        expire = utcnow_naive() + (expires_delta or settings.jwt_exp)
        to_encode.update({'exp': expire})
        encoded_jwt = await run_in_threadpool(
            jwt.encode,  # type: ignore[arg-type]
            claims=to_encode,
            key=settings.jwt_secret_key,
            algorithm=settings.jwt_algorithm,
        )
        return encoded_jwt

    async def _get_or_create_user(
        self,
        request: Request,
        session: AsyncSession,
        firebase_claims: dict[str, Any],
    ) -> User:
        """Get a user from the database or create one if it doesn't exist."""
        user_repo = UserRepository(session)
        user = await user_repo.get_by_firebase_uid(firebase_claims['uid'])

        if user:
            # Update user from claims - updates login streak, updated_at, etc.
            user = await user_repo.login_user(user, firebase_claims)
        else:
            # Create new user
            # Provide a random avatar and display name if needed
            firebase_claims = enrich_firebase_claims(request, firebase_claims)
            user = await user_repo.register_user(firebase_claims)

        return user

    async def authenticate_user(
        self,
        request: Request,
        session: AsyncSession,
        firebase_token: str,
    ) -> tuple[User, Token] | None:
        """Authenticate a user with a Firebase token."""
        use_emulators = os.getenv('USE_EMULATORS', 'false').lower() == 'true'

        if use_emulators:
            # Validate token via Auth emulator accounts:lookup
            emulator_host = os.environ.get('FIREBASE_AUTH_EMULATOR_HOST') or ''
            firebase_claims = await _get_emulator_claims(firebase_token, emulator_host)
        else:
            try:
                # Use a thread pool for the blocking I/O call
                firebase_claims: dict[str, Any] = await run_in_threadpool(
                    auth.verify_id_token,  # type: ignore[arg-type]
                    firebase_token,
                    check_revoked=True,
                )
            except (
                ValueError,
                auth.InvalidIdTokenError,
                auth.ExpiredIdTokenError,
                auth.RevokedIdTokenError,
                auth.CertificateFetchError,
                auth.UserDisabledError,
            ) as exc:
                raise InvalidFirebaseTokenError from exc

        user = await self._get_or_create_user(request, session, firebase_claims)
        access_token = await self._create_access_token(
            to_encode={'user_id': user.id},
        )
        return user, Token(access_token=access_token, token_type='bearer')  # noqa: S106  # nosec: CWE-259

    async def refresh_access_token(
        self,
        session: AsyncSession,
        token_str: str,
    ) -> tuple[User, Token]:
        """Decode an existing access token (ignoring expiration) and mint a new one.

        This allows refreshing tokens without requiring the client to hold the
        Firebase ID token. We verify signature with the configured secret and
        algorithm but disable exp verification to allow expired tokens within
        a grace-less, stateless flow. The caller is responsible for guarding
        this endpoint appropriately.
        """
        # Decode without verifying expiration; still verify signature/alg
        payload: dict[str, Any] = await run_in_threadpool(
            jwt.decode,  # type: ignore[arg-type]
            token_str,
            settings.jwt_secret_key,
            [settings.jwt_algorithm],
            options={'verify_exp': False},
        )
        user_id = payload.get('user_id')
        if not isinstance(user_id, int):
            raise InvalidFirebaseTokenError

        # Ensure the user still exists
        user_repo = UserRepository(session)
        user = await user_repo.get_by_id(user_id)
        if user is None:
            raise InvalidFirebaseTokenError

        access_token = await self._create_access_token(
            to_encode={'user_id': user.id},
        )
        return user, Token(access_token=access_token, token_type='bearer')  # noqa: S106

    def sign_out(self, user_id: str, response: 'Response') -> None:
        """Sign out a user."""
        # Revoke refresh tokens
        auth.revoke_refresh_tokens(user_id)
        response.delete_cookie('access_token')
