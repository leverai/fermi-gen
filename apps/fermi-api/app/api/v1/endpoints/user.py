"""User endpoints."""

from typing import TYPE_CHECKING, Annotated, Literal

from fastapi import APIRouter, Depends, Request, status
from fermi_db.models.user import User
from fermi_db.repositories.party_hosting_repository import PartyHostingRepository
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_authenticated_user, get_current_user
from app.api.v1.authenticated_user import AuthenticatedUser
from app.api.v1.dependencies import (
    get_game_service,
    get_party_hosting_repository,
    get_survival_run_repository,
    get_user_service,
)
from app.schemas.endpoints import (
    SetLocaleRequest,
    UpdateUserProfileRequest,
    UserLimitsResponse,
)
from app.services.game.service import GameService
from app.services.user import UserService

if TYPE_CHECKING:
    from fermi_db.repositories.survival_run_repository import SurvivalRunRepository

router = APIRouter()


@router.post('/set_locale')
async def set_locale(
    payload: SetLocaleRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Set a user's locale."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, set_locale.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'locale={payload.locale}')
    assert current_user.id is not None
    await user_service.set_locale(
        user_id=current_user.id,
        locale=payload.locale,
    )
    return status.HTTP_200_OK


@router.post('/update_profile')
async def update_profile(
    request: Request,
    payload: UpdateUserProfileRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Update a user's profile."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, update_profile.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, payload.model_dump_json())
    assert current_user.id is not None

    # Convert relative avatar path to absolute URL if needed
    # Frontend sends paths like /static/avatars/letters/a.svg
    # We need to store absolute URLs for the frontend's SvgPicture.network
    picture_url = payload.avatar_url
    if picture_url and picture_url.startswith('/static/avatars/'):
        base_url = str(request.base_url).rstrip('/')
        picture_url = f'{base_url}{picture_url}'

    # Validate avatar is unlocked for user's level
    if payload.avatar_url and '/static/avatars/' in payload.avatar_url:
        from fastapi import HTTPException

        from app.services.avatars import get_avatar_unlock_level

        # Extract filename from URL (may include group subdirectory)
        # e.g., "http://x/static/avatars/animals/foo.svg" -> "foo.svg"
        path_after_avatars = payload.avatar_url.split('/static/avatars/')[-1]
        filename = path_after_avatars.split('/')[-1]  # Get just the filename

        try:
            required_level = get_avatar_unlock_level(filename)
            xp_level = await user_service.get_xp_level(current_user.firebase_uid)
            user_level = xp_level['level']
            if user_level < required_level:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        f'Avatar requires level {required_level}, '
                        f'you are level {user_level}'
                    ),
                )
        except KeyError:
            pass  # Unknown avatars (e.g., OAuth provider images) are allowed

    await user_service.update_user_profile(
        user_id=current_user.id,
        display_name=payload.display_name,
        picture=picture_url,
    )
    return status.HTTP_200_OK


@router.post('/delete')
async def delete_user(
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Delete a user and all associated data."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, delete_user.__qualname__)
    assert current_user.id is not None
    await user_service.delete_user(user_id=current_user.id)
    return status.HTTP_200_OK


@router.get('/limits', response_model=UserLimitsResponse)
async def get_user_limits(
    auth_user: Annotated[AuthenticatedUser, Depends(get_authenticated_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
    hosting_repo: Annotated[
        PartyHostingRepository,
        Depends(get_party_hosting_repository),
    ],
    survival_run_repo: Annotated[
        'SurvivalRunRepository',
        Depends(get_survival_run_repository),
    ],
) -> UserLimitsResponse:
    """Get user-specific limits based on subscription tier.

    This returns dynamic data that changes with user actions (e.g., party
    game hosting count, survival run count). Should be fetched after actions
    that affect limits.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_user_limits.__qualname__)
    limits = await game_service.get_user_limits(
        user_id=auth_user.id,
        user_firebase_uid=auth_user.firebase_uid,
        hosting_repo=hosting_repo,
        survival_run_repo=survival_run_repo,
        is_pro=auth_user.is_pro,
    )
    return UserLimitsResponse(limits=limits)
