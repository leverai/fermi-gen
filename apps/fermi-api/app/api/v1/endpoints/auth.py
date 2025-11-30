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
from fermi_db.models.user import User
from fermi_db.session import get_session
from sqlmodel.ext.asyncio.session import AsyncSession

from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_auth_service
from app.schemas.auth import TokenResponse, UserResponse
from app.services.auth import AuthService
from app.services.errors import InvalidFirebaseTokenError

router = APIRouter()
bearer_scheme = HTTPBearer()


@router.post('/token', response_model=TokenResponse)
async def verify_token(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials, Security(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> TokenResponse:
    """Verify a Firebase token and return an access token."""
    try:
        auth_result = await auth_service.authenticate_user(
            request=request,
            session=session,
            firebase_token=credentials.credentials,
        )
    except InvalidFirebaseTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authentication credentials',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc
    if auth_result is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authentication credentials',
            headers={'WWW-Authenticate': 'Bearer'},
        )

    user, token = auth_result
    return TokenResponse(
        access_token=token.access_token,
        token_type=token.token_type,
        user=UserResponse(
            firebase_uid=user.firebase_uid,
            email=user.email,
            display_name=user.display_name,
            picture=user.picture,
            locale=user.locale,
        ),
    )


@router.post('/refresh', response_model=TokenResponse)
async def refresh_token(
    credentials: Annotated[HTTPAuthorizationCredentials, Security(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_session)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> TokenResponse:
    """Refresh a JWT access token.

    Accepts an existing access token via Authorization: Bearer <token> and returns
    a new access token for the same user if the token's signature is valid.
    """
    try:
        user, token = await auth_service.refresh_access_token(
            session=session,
            token_str=credentials.credentials,
        )
    except Exception as exc:  # broad: map to 401 to avoid information leaks
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authentication credentials',
            headers={'WWW-Authenticate': 'Bearer'},
        ) from exc

    return TokenResponse(
        access_token=token.access_token,
        token_type=token.token_type,
        user=UserResponse(
            firebase_uid=user.firebase_uid,
            email=user.email,
            display_name=user.display_name,
            picture=user.picture,
            locale=user.locale,
        ),
    )


@router.post('/sign-out')
async def sign_out(
    response: Response,
    user: Annotated[User, Depends(get_current_user)],
    auth_service: Annotated[AuthService, Depends(get_auth_service)],
) -> Literal[200]:
    """Sign out a user."""
    auth_service.sign_out(user_id=user.firebase_uid, response=response)
    return 200
