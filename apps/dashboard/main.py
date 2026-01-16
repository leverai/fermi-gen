"""FastAPI entrypoint for the Fermi Dashboard."""

import logging
import os
import secrets
from pathlib import Path

from dotenv import load_dotenv

# CRITICAL: Load environment variables BEFORE importing any app modules
# The fermi_db.session module creates the database engine at import time,
# so DATABASE_URL must be set before that happens.
env_file = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_file)

# Handle environment-based DATABASE_URL selection for deployed environments
# If ENVIRONMENT is set (dev/prod), use the corresponding DATABASE_URL_DEV/PROD
environment = os.getenv('ENVIRONMENT')
if environment:
    env_db_url = os.getenv(f'DATABASE_URL_{environment.upper()}')
    if env_db_url:
        os.environ['DATABASE_URL'] = env_db_url

# Now we can import app modules (which will import fermi_db with correct DATABASE_URL)
from fastapi import Depends, FastAPI, HTTPException, status  # noqa: E402
from fastapi.responses import FileResponse  # noqa: E402
from fastapi.security import HTTPBasic, HTTPBasicCredentials  # noqa: E402
from fastapi.staticfiles import StaticFiles  # noqa: E402
from fermi_core.logging_utils import setup_logging  # noqa: E402

from app.api.router import router  # noqa: E402
from app.version import __version__  # noqa: E402

# Setup logging
setup_logging()
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title='Fermi Dashboard',
    description='Admin dashboard for auditing Fermi questions',
    version=__version__,
)

# HTTP Basic Auth setup
security = HTTPBasic()
AUTH_USERNAME = os.getenv('AUTH_USERNAME')
AUTH_PASSWORD = os.getenv('AUTH_PASSWORD')


def verify_credentials(credentials: HTTPBasicCredentials = Depends(security)) -> str:  # noqa: B008
    """Verify HTTP Basic Auth credentials."""
    if not AUTH_USERNAME or not AUTH_PASSWORD:
        # Auth not configured - allow access (for local dev)
        return credentials.username

    correct_username = secrets.compare_digest(
        credentials.username.encode('utf-8'),
        AUTH_USERNAME.encode('utf-8'),
    )
    correct_password = secrets.compare_digest(
        credentials.password.encode('utf-8'),
        AUTH_PASSWORD.encode('utf-8'),
    )
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid credentials',
            headers={'WWW-Authenticate': 'Basic'},
        )
    return credentials.username


# Register API router with auth dependency if auth is configured
if AUTH_USERNAME and AUTH_PASSWORD:
    app.include_router(router, dependencies=[Depends(verify_credentials)])
else:
    app.include_router(router)

# Serve static files (HTML, CSS, JS)
static_dir = Path(__file__).parent / 'static'
if static_dir.exists():
    app.mount('/static', StaticFiles(directory=str(static_dir)), name='static')


@app.get('/')
async def root(
    _: str = Depends(verify_credentials) if AUTH_USERNAME and AUTH_PASSWORD else None,
) -> FileResponse:
    """Serve the dashboard page."""
    return FileResponse(static_dir / 'index.html')


@app.get('/health')
async def health() -> dict[str, str]:
    """Health check endpoint (no auth required)."""
    return {'status': 'healthy'}


if __name__ == '__main__':
    import uvicorn

    uvicorn.run(app, host='0.0.0.0', port=8000)  # noqa: S104
