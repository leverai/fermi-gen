"""FastAPI entrypoint for the Fermi ETL Pipeline."""

import logging

from fastapi import FastAPI
from fermi_core.logging_utils import setup_logging

from app.api import answers, composite, enrichment, questions, seeds
from app.version import __version__

# Setup logging
setup_logging()
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title='Fermi ETL Pipeline',
    description='Unified ETL pipeline for Fermi question generation and management',
    version=__version__,
)

# Register routers
app.include_router(seeds.router, prefix='/seeds', tags=['Seeds'])
app.include_router(questions.router, prefix='/questions', tags=['Questions'])
app.include_router(answers.router, prefix='/answers', tags=['Answers'])
app.include_router(enrichment.router, prefix='/enrich', tags=['Enrichment'])
app.include_router(composite.router, tags=['Composite Workflows'])


@app.get('/')
async def root() -> dict[str, str]:
    """Root endpoint with service information."""
    return {
        'service': 'fermi-etl',
        'version': __version__,
        'status': 'healthy',
        'description': 'Unified ETL pipeline for Fermi question generation',
    }


@app.get('/health')
async def health() -> dict[str, str]:
    """Health check endpoint."""
    return {'status': 'healthy'}


if __name__ == '__main__':
    import uvicorn

    uvicorn.run(app, host='0.0.0.0', port=8080)  # noqa: S104
