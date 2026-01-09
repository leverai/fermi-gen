"""Authentication Dependencies for injection in endpoints."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from fermi_db.models.subscription import SubscriptionTier
from fermi_db.models.user import User
from fermi_db.repositories.subscription_repository import SubscriptionRepository
from fermi_db.repositories.user_repository import UserRepository
from fermi_db.session import get_session
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JWTClaimsError, JWTError
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from pydantic import ValidationError
from sqlmodel.ext.asyncio.session import AsyncSession
from starlette.concurrency import run_in_threadpool

import app.logging.attributes as api_attrs
from app.api.v1.authenticated_user import AuthenticatedUser
from app.api.v1.dependencies import get_subscription_repository
from app.core.config import settings
from app.schemas.auth import TokenPayload

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f'{settings.api_v1_str}/auth/token')


def get_user_repository(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserRepository:
    """Get a user repository."""
    return UserRepository(session)


async def get_current_user(
    user_repo: Annotated[UserRepository, Depends(get_user_repository)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Get the current user from a token."""
    span = trace.get_current_span()
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

    user = await user_repo.get_by_id(token_data.user_id)
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

    # Enrich span with authenticated user info
    span.set_attribute(api_attrs.FIREBASE_UID, user.firebase_uid)

    return user


async def get_authenticated_user(
    user: Annotated[User, Depends(get_current_user)],
    subscription_repo: Annotated[
        SubscriptionRepository,
        Depends(get_subscription_repository),
    ],
) -> AuthenticatedUser:
    """Get the current user with their subscription tier.

    Use this dependency instead of get_current_user when you need to check
    subscription status for feature gating.
    """
    assert user.id is not None
    subscription = await subscription_repo.get_by_user_id(user.id)

    # Determine tier: PRO only if subscription exists and is active
    tier = SubscriptionTier.FREE
    if subscription is not None and subscription.is_active:
        tier = subscription.tier

    return AuthenticatedUser(user=user, tier=tier)
