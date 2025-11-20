"""API endpoints for seed operations."""

import logging

from fastapi import APIRouter

from app.config import get_config
from app.schemas.requests import SeedInsertRequest
from app.schemas.responses import SeedInsertResponse
from app.services.seed_service import insert_seeds

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post('/insert_literal', response_model=SeedInsertResponse)
async def insert_literal(request: SeedInsertRequest) -> SeedInsertResponse:
    """Manually insert seeds into the database.

    Seeds will be:
    1. Preprocessed (lowercase, normalized, cleaned)
    2. Validated (length, content checks)
    3. Embedded using OpenAI embeddings
    4. Checked for uniqueness against existing seeds
    5. Inserted if unique (based on threshold)

    Args:
        request: Seed insertion request with list of seed texts

    Returns:
        SeedInsertResponse with detailed results for each seed

    """
    logger.info(
        'Received seed insertion request for %d seeds',
        len(request.seeds),
    )

    try:
        config = get_config()
        result = await insert_seeds(
            seed_texts=request.seeds,
            config=config,
        )

        logger.info(f'Seed insertion successful: {result}')
        return SeedInsertResponse(success=True, result=result)

    except Exception as exc:
        logger.error(f'Seed insertion failed: {exc}', exc_info=True)
        return SeedInsertResponse(
            success=False,
            error=str(exc),
        )
