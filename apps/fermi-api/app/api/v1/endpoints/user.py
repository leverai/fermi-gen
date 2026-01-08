"""User endpoints."""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, status
from fermi_db.models.user import User
from opentelemetry import trace

import app.logging.attributes as api_attrs
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
    payload: UpdateUserProfileRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> Literal[200]:
    """Update a user's profile."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, update_profile.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, payload.model_dump_json())
    assert current_user.id is not None

    # Validate avatar is unlocked for user's level
    if payload.avatar_url and '/static/avatars/' in payload.avatar_url:
        from fastapi import HTTPException

        from app.services.avatars import AVATARS, get_avatar_unlock_level

        # Extract filename from URL
        # e.g., "http://x/static/avatars/foo.svg" -> "foo.svg"
        filename = payload.avatar_url.split('/static/avatars/')[-1]
        if filename in AVATARS:
            xp_level = await user_service.get_xp_level(current_user.firebase_uid)
            user_level = xp_level['level']
            required_level = get_avatar_unlock_level(filename)
            if user_level < required_level:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        f'Avatar requires level {required_level}, '
                        f'you are level {user_level}'
                    ),
                )

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
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, delete_user.__qualname__)
    assert current_user.id is not None
    await user_service.delete_user(user_id=current_user.id)
    return status.HTTP_200_OK
