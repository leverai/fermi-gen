"""Authentication Dependencies for injection in endpoints."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from fermi_db.models.user import User
from fermi_db.repositories.user_repository import UserRepository
from fermi_db.session import get_session
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JWTClaimsError, JWTError
from opentelemetry import trace
from opentelemetry.trace import Span, Status, StatusCode
from pydantic import ValidationError
from sqlmodel.ext.asyncio.session import AsyncSession
from starlette.concurrency import run_in_threadpool

import app.logging.attributes as api_attrs
from app.api.v1.authenticated_user import AuthenticatedUser
from app.core.config import settings
from app.schemas.auth import TokenPayload

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f'{settings.api_v1_str}/auth/token')


def get_user_repository(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserRepository:
    """Get a user repository."""
    return UserRepository(session)


async def _validate_jwt_token(token: str, span: Span) -> int:
    """Validate JWT token and extract user_id.

    Args:
        token: The JWT bearer token.
        span: Current OpenTelemetry span for error recording.

    Returns:
        The user_id from the token payload.

    Raises:
        HTTPException: 401 if token is invalid, expired, or missing claims.

    """
    try:
        payload = await run_in_threadpool(
            jwt.decode,  # type: ignore[arg-type]
            token,
            key=settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        token_data = TokenPayload(**payload)
    except ExpiredSignatureError as exc:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Token has expired',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc
    except JWTError as exc:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Could not validate signature',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc
    except (JWTClaimsError, ValidationError) as exc:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid claims',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc

    if not token_data.user_id:
        span.set_status(Status(StatusCode.ERROR))
        exception = ValueError('Missing claims in token')
        span.record_exception(exception)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Missing claims in token',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exception

    span.set_attribute(api_attrs.USER_ID, token_data.user_id)
    return token_data.user_id


async def get_current_user(
    user_repo: Annotated[UserRepository, Depends(get_user_repository)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Get the current user from a token."""
    span = trace.get_current_span()
    user_id = await _validate_jwt_token(token, span)

    user = await user_repo.get_by_id(user_id)
    if user is None:
        span.set_status(Status(StatusCode.ERROR))
        exception = ValueError('User not found')
        span.record_exception(exception)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='User not found',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exception
    assert user.id is not None

    span.set_attribute(api_attrs.FIREBASE_UID, user.firebase_uid)
    return user


async def get_authenticated_user(
    user_repo: Annotated[UserRepository, Depends(get_user_repository)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> AuthenticatedUser:
    """Get the current user with their subscription tier.

    Use this dependency instead of get_current_user when you need to check
    subscription status for feature gating.

    Uses a single JOIN query to fetch user and tier together.
    """
    span = trace.get_current_span()
    user_id = await _validate_jwt_token(token, span)

    result = await user_repo.get_user_with_tier(user_id)
    if result is None:
        span.set_status(Status(StatusCode.ERROR))
        exception = ValueError('User not found')
        span.record_exception(exception)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='User not found',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exception

    user, tier = result
    assert user.id is not None

    span.set_attribute(api_attrs.FIREBASE_UID, user.firebase_uid)
    span.set_attribute(api_attrs.USER_TIER, tier.name)

    return AuthenticatedUser(user=user, tier=tier)


def require_pro(
    auth_user: AuthenticatedUser,
    feature_name: str = 'This feature',
) -> None:
    """Raise 403 if user does not have Pro subscription.

    Use this helper in tier-gated endpoints after getting AuthenticatedUser.

    Args:
        auth_user: The authenticated user with subscription tier.
        feature_name: Name of the feature for the error message.

    Raises:
        HTTPException: 403 if user is not Pro.

    Example:
        >>> auth_user: Annotated[AuthenticatedUser, Depends(get_authenticated_user)]
        >>> require_pro(auth_user, 'Archive access')

    """
    if not auth_user.is_pro:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f'{feature_name} requires Pro subscription',
        )
