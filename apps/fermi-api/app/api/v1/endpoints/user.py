"""User endpoints."""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, status
from fermi_db.models.user import User

from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_user_service
from app.schemas.endpoints import SetLocaleRequest, UpdateUserProfileRequest
from app.services.user import UserService

router = APIRouter()


@router.post('/set_locale')
async def set_locale(
    payload: SetLocaleRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Set a user's locale."""
    assert current_user.id is not None
    await user_service.set_locale(
        user_id=current_user.id,
        locale=payload.locale,
    )
    return status.HTTP_200_OK


@router.post('/update_profile')
async def update_profile(
    payload: UpdateUserProfileRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Update a user's profile."""
    assert current_user.id is not None
    await user_service.update_user_profile(
        user_id=current_user.id,
        display_name=payload.display_name,
        picture=payload.avatar_url,
    )
    return status.HTTP_200_OK


@router.post('/delete')
async def delete_user(
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Delete a user and all associated data."""
    assert current_user.id is not None
    await user_service.delete_user(user_id=current_user.id)
    return status.HTTP_200_OK
