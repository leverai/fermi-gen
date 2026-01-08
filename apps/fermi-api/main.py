"""Main entry point for the Guesstimate Game backend.

This module provides a simple entry point to run the application.
"""

import contextlib
import logging
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api.api import api_router
from app.api.v1.rate_limit import limiter
from app.core.config import settings
from app.logging.otel import instrument_fastapi
from app.logging.setup import setup_api_logging
from app.version import __version__

# Initialize structured logging and OpenTelemetry before anything else
setup_api_logging()

logger = logging.getLogger(__name__)


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """App lifespan: startup DB init, shutdown engine dispose.

    Ensures async SQLAlchemy engine and pool are disposed cleanly to avoid
    lingering pooled connections triggering GC warnings or teardown hangs.
    """
    try:
        yield
    finally:
        # Dispose engine to return pooled connections deterministically
        try:
            from fermi_db.session import async_engine  # local import to avoid cycles

            await async_engine.dispose()
        except Exception:  # best-effort cleanup
            logger.exception('Error disposing engine')
            pass


def create_app() -> FastAPI:
    """Create the FastAPI application."""
    app = FastAPI(
        title=settings.project_name,
        version=__version__,
        openapi_url=f'{settings.api_v1_str}/openapi.json',
        lifespan=lifespan,
    )

    app.include_router(api_router, prefix=settings.api_v1_str)
    # Serve static assets (e.g., category images)
    app.mount('/static', StaticFiles(directory='static'), name='static')
    return app


app = create_app()

# Register rate limiter state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Instrument with OpenTelemetry for automatic tracing
instrument_fastapi(app)

# Define the origins that are allowed to make requests.
# For production, restrict this to your actual frontend's domain.
origins = [
    # Deployed Flutter web app
    'https://guesstimate-5483f.web.app',
    # Local development
    'http://localhost',
    'http://localhost:8080',
    'http://localhost:3000',
    'http://127.0.0.1:8080',
    'http://127.0.0.1:3000',
]

# Add the CORS middleware to your application
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=['*'],  # Allows all methods (GET, POST, etc.)
    allow_headers=['*'],  # Allows all headers
)


def main() -> None:
    """Initialize and run the Guesstimate Game backend."""
    logger.info('Starting Guesstimate Game backend')


if __name__ == '__main__':
    main()
