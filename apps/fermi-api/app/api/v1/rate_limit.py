"""Rate limiting configuration for API endpoints."""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Per-IP limiter for unauthenticated endpoints
limiter = Limiter(key_func=get_remote_address)

# Rate limit strings
AUTH_RATE_LIMIT = '10/minute'  # Auth endpoints
GAME_CREATE_RATE_LIMIT = '10/minute'  # Game creation
DQ_START_RATE_LIMIT = '5/minute'  # DQ start
