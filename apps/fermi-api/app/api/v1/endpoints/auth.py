"""Auth endpoints."""

from typing import Annotated, Literal

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Request,
    Response,
    Security,
    status,
)
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fermi_db.models.subscription import SubscriptionTier
from fermi_db.models.user import User
from fermi_db.repositories.subscription_repository import SubscriptionRepository
from fermi_db.session import get_session
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from sqlmodel.ext.asyncio.session import AsyncSession

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import (
    get_auth_service,
    get_subscription_repository,
)
from app.schemas.auth import TokenResponse, UserResponse
from app.services.auth import AuthService
from app.services.errors import InvalidFirebaseTokenError

router = APIRouter()
bearer_scheme = HTTPBearer()


async def _get_subscription_tier(
    user_id: int,
    subscription_repository: SubscriptionRepository,
) -> str:
    """Get subscription tier for a user."""
    subscription = await subscription_repository.get_by_user_id(user_id)
    if subscription and subscription.is_active:
        return subscription.tier.value
    return SubscriptionTier.FREE.value


@router.post('/token', response_model=TokenResponse)
async def verify_token(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials, Security(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
    subscription_repository: Annotated[
        SubscriptionRepository,
        Depends(get_subscription_repository),
    ],
) -> TokenResponse:
    """Verify a Firebase token and return an access token."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, verify_token.__qualname__)

    try:
        auth_result = await auth_service.authenticate_user(
            request=request,
            session=session,
            firebase_token=credentials.credentials,
        )
    except InvalidFirebaseTokenError as exc:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authentication credentials',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc
    if auth_result is None:
        span.set_status(Status(StatusCode.ERROR))
        exception = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authentication credentials',
            headers={'WWW-Authenticate': 'Bearer'},
        )
        span.record_exception(exception)
        raise exception

    user, token = auth_result
    assert user.id is not None, 'User ID should be set after authentication'
    span.set_attribute(api_attrs.USER_ID, user.id)
    span.set_attribute(api_attrs.FIREBASE_UID, user.firebase_uid)

    subscription_tier = await _get_subscription_tier(user.id, subscription_repository)
    span.set_attribute(api_attrs.USER_TIER, subscription_tier)

    return TokenResponse(
        access_token=token.access_token,
        token_type=token.token_type,
        user=UserResponse(
            firebase_uid=user.firebase_uid,
            email=user.email,
            display_name=user.display_name,
            picture=user.picture,
            locale=user.locale,
            subscription_tier=subscription_tier,
        ),
    )


@router.post('/refresh', response_model=TokenResponse)
async def refresh_token(
    credentials: Annotated[HTTPAuthorizationCredentials, Security(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
    subscription_repository: Annotated[
        SubscriptionRepository,
        Depends(get_subscription_repository),
    ],
) -> TokenResponse:
    """Refresh a JWT access token.

    Accepts an existing access token via Authorization: Bearer <token> and returns
    a new access token for the same user if the token's signature is valid.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, refresh_token.__qualname__)

    try:
        user, token = await auth_service.refresh_access_token(
            session=session,
            token_str=credentials.credentials,
        )
    except Exception as exc:  # broad: map to 401 to avoid information leaks
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authentication credentials',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc

    assert user.id is not None, 'User ID should be set after token refresh'
    span.set_attribute(api_attrs.USER_ID, user.id)
    span.set_attribute(api_attrs.FIREBASE_UID, user.firebase_uid)

    subscription_tier = await _get_subscription_tier(user.id, subscription_repository)
    span.set_attribute(api_attrs.USER_TIER, subscription_tier)

    return TokenResponse(
        access_token=token.access_token,
        token_type=token.token_type,
        user=UserResponse(
            firebase_uid=user.firebase_uid,
            email=user.email,
            display_name=user.display_name,
            picture=user.picture,
            locale=user.locale,
            subscription_tier=subscription_tier,
        ),
    )


@router.post('/sign-out')
async def sign_out(
    response: Response,
    user: Annotated[User, Depends(get_current_user)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> Literal[200]:
    """Sign out a user."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, sign_out.__qualname__)

    auth_service.sign_out(user_id=user.firebase_uid, response=response)
    return 200
