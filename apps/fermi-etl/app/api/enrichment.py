"""API endpoints for enrichment operations (category, difficulty)."""

import logging

from fastapi import APIRouter
from fermi_db.dal import DatabaseClient
from fermi_db.session import session_context

from app.config import get_config
from app.schemas.requests import EnrichmentRequest
from app.schemas.responses import EnrichmentResponse
from app.services.enrichment_service import enrich_categories, enrich_difficulties

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post('/category', response_model=EnrichmentResponse)
async def enrich_category(request: EnrichmentRequest) -> EnrichmentResponse:
    """Enrich questions with category classifications.

    Args:
        request: Request with num_questions

    Returns:
        EnrichmentResponse with statistics

    """
    logger.info(
        f'Received category enrichment request for {request.num_questions} questions',
    )

    try:
        config = get_config()
        result = await enrich_categories(
            limit=request.num_questions,
            config=config,
        )

        logger.info(
            f'Category enrichment successful: '
            f'enriched={result.enriched}, skipped={result.skipped}',
        )
        return EnrichmentResponse(success=True, result=result)

    except Exception as exc:
        logger.error(f'Category enrichment failed: {exc}', exc_info=True)
        return EnrichmentResponse(
            success=False,
            error=str(exc),
        )


@router.post('/difficulty', response_model=EnrichmentResponse)
async def enrich_difficulty(request: EnrichmentRequest) -> EnrichmentResponse:
    """Enrich questions with difficulty classifications.

    Args:
        request: Request with num_questions

    Returns:
        EnrichmentResponse with statistics

    """
    logger.info(
        f'Received difficulty enrichment request for {request.num_questions} questions',
    )

    try:
        config = get_config()
        result = await enrich_difficulties(
            limit=request.num_questions,
            config=config,
        )

        logger.info(
            f'Difficulty enrichment successful: '
            f'enriched={result.enriched}, skipped={result.skipped}',
        )
        return EnrichmentResponse(success=True, result=result)

    except Exception as exc:
        logger.error(f'Difficulty enrichment failed: {exc}', exc_info=True)
        return EnrichmentResponse(
            success=False,
            error=str(exc),
        )


@router.post('/join_all', response_model=EnrichmentResponse)
async def join_all() -> EnrichmentResponse:
    """Sync the fermi table with new enriched questions.

    Inserts questions that have:
    - Successful answers
    - All three LLM answers
    - Are not yet in the fermi table

    New questions are inserted with status = PENDING_REVIEW.

    Returns:
        EnrichmentResponse with count of new questions inserted

    """
    logger.info('Received request to sync fermi table')

    try:
        async with session_context() as session:
            db_client = DatabaseClient(session)
            count = await db_client.enrichment.sync_fermi_table()

        logger.info(f'Fermi table sync successful: {count} questions added')
        return EnrichmentResponse(
            success=True,
            result={'questions_added': count},
        )

    except Exception as exc:
        logger.error(f'Fermi table sync failed: {exc}', exc_info=True)
        return EnrichmentResponse(
            success=False,
            error=str(exc),
        )
