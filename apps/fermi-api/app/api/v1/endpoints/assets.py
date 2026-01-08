"""Endpoints to serve assets."""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fermi_db.models.user import User
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_user_service
from app.api.v1.rate_limit import ASSETS_RATE_LIMIT, limiter
from app.schemas.endpoints import AvatarInfo, GetAvatarsResponse
from app.services.avatars import AVATARS, is_avatar_unlocked
from app.services.user import UserService

router = APIRouter()


@router.get('/avatars', response_model=GetAvatarsResponse)
@limiter.limit(ASSETS_RATE_LIMIT)
async def get_avatars(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> GetAvatarsResponse:
    """Return a list of all avatars with unlock metadata."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_avatars.__qualname__)
    span.set_attribute(api_attrs.FIREBASE_UID, current_user.firebase_uid)

    # Get user's level
    xp_level = await user_service.get_xp_level(current_user.firebase_uid)
    user_level = xp_level['level']

    # Build avatar list with metadata
    base_url = str(request.base_url).rstrip('/')
    avatars = [
        AvatarInfo(
            url=f'{base_url}/static/avatars/{filename}',
            unlock_level=unlock_level,
            unlocked=is_avatar_unlocked(filename, user_level),
        )
        for filename, unlock_level in AVATARS.items()
    ]
    # Sort by unlock level for better UX
    avatars.sort(key=lambda a: (a.unlock_level, a.url))

    return GetAvatarsResponse(avatars=avatars)
