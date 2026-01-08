"""Rate limiting configuration for API endpoints."""

import os

from slowapi import Limiter
from slowapi.util import get_remote_address

# Enable rate limiting only when deployed on Cloud Run
# K_SERVICE is automatically set by Cloud Run
_enabled = 'K_SERVICE' in os.environ

# Per-IP limiter for unauthenticated endpoints
limiter = Limiter(key_func=get_remote_address, enabled=_enabled)

# Rate limit strings
AUTH_RATE_LIMIT = '10/minute'  # Auth endpoints
GAME_CREATE_RATE_LIMIT = '10/minute'  # Game creation
DQ_START_RATE_LIMIT = '5/minute'  # DQ start
