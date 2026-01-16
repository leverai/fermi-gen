"""FastAPI entrypoint for the Fermi Dashboard."""

import logging
from pathlib import Path

from dotenv import load_dotenv

# CRITICAL: Load environment variables BEFORE importing any app modules
# The fermi_db.session module creates the database engine at import time,
# so DATABASE_URL must be set before that happens.
env_file = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_file)

# Now we can import app modules (which will import fermi_db with correct DATABASE_URL)
from fastapi import FastAPI  # noqa: E402
from fastapi.responses import FileResponse  # noqa: E402
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

# Register API router
app.include_router(router)

# Serve static files (HTML, CSS, JS)
static_dir = Path(__file__).parent / 'static'
if static_dir.exists():
    app.mount('/static', StaticFiles(directory=str(static_dir)), name='static')


@app.get('/')
async def root() -> FileResponse:
    """Serve the dashboard page."""
    return FileResponse(static_dir / 'index.html')


@app.get('/health')
async def health() -> dict[str, str]:
    """Health check endpoint."""
    return {'status': 'healthy'}


if __name__ == '__main__':
    import uvicorn

    uvicorn.run(app, host='0.0.0.0', port=8000)  # noqa: S104
