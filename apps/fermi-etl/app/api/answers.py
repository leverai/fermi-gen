"""API endpoints for answer operations."""

import logging
import traceback

from fastapi import APIRouter

from app.config import get_config
from app.schemas.requests import AnswerUnansweredRequest
from app.schemas.responses import AnswerResponse
from app.services.answer_service import answer_unanswered_questions

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post('/insert_serp', response_model=AnswerResponse)
async def insert_serp(request: AnswerUnansweredRequest) -> AnswerResponse:
    """Answer the latest N unanswered questions using SERP API.

    Process:
    1. Query database for latest unanswered questions (ORDER BY created_at DESC)
    2. Call SERP API to generate answers
    3. Store successful answers in database
    4. Return statistics

    Args:
        request: Answer request with num_questions (default 50)

    Returns:
        AnswerResponse with statistics

    """
    logger.info(
        f'Received answer request for {request.num_questions} unanswered questions',
    )

    try:
        config = get_config()
        result = await answer_unanswered_questions(
            num_questions=request.num_questions,
            location_model=request.location_model,
            extraction_model=request.extraction_model,
            model_provider=request.answer_model_provider,
            confidence_threshold=request.confidence_threshold,
            config=config,
        )

        logger.info(f'Answer generation successful: {result}')
        return AnswerResponse(success=True, result=result)

    except Exception:
        exc_traceback = traceback.format_exc()
        logger.error(f'Answer generation failed: {exc_traceback}', exc_info=True)
        return AnswerResponse(
            success=False,
            error=exc_traceback,
        )
