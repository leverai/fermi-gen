"""Endpoints to serve assets."""

from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.security import HTTPBearer
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.schemas.endpoints import GetAvatarsResponse

router = APIRouter()
bearer_scheme = HTTPBearer()

ASSETS_DIR = Path('static')
AVATAR_DIR = ASSETS_DIR / 'avatars'


@router.get('/avatars', response_model=GetAvatarsResponse)
async def get_avatars(request: Request) -> GetAvatarsResponse:
    """Return a list of all avatars."""
    # Pre-calculate the base or use url_for for safety
    # glob is a generator, so we can use a list comprehension
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_avatars.__qualname__)

    base_url = str(request.base_url).rstrip('/')
    urls = [f'{base_url}/{path!s}' for path in AVATAR_DIR.glob('*.svg')]
    return GetAvatarsResponse(avatars=urls)
