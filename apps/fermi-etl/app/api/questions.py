"""API endpoints for question operations."""

import logging

from fastapi import APIRouter

from app.config import get_config
from app.schemas.requests import QuestionLiteralRequest, QuestionLLMRequest
from app.schemas.responses import QuestionResponse
from app.services.question_service import (
    insert_literal_questions,
    insert_llm_questions,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post('/insert_literal', response_model=QuestionResponse)
async def insert_literal(request: QuestionLiteralRequest) -> QuestionResponse:
    """Insert user-provided questions directly.

    Questions will be:
    1. Validated (length, content checks)
    2. Embedded using OpenAI embeddings
    3. Inserted as raw questions
    4. Deduplicated against existing questions
    5. Only unique questions will be stored

    Args:
        request: Question insertion request with list of question texts

    Returns:
        QuestionResponse with statistics and new question IDs

    """
    logger.info(
        'Received literal question insertion request for %d questions',
        len(request.questions),
    )

    try:
        config = get_config()
        result = await insert_literal_questions(
            question_texts=request.questions,
            provider=request.provider,
            config=config,
        )

        logger.info(f'Literal question insertion successful: {result}')
        return QuestionResponse(success=True, result=result)

    except Exception as exc:
        logger.error(f'Literal question insertion failed: {exc}', exc_info=True)
        return QuestionResponse(
            success=False,
            error=str(exc),
        )


@router.post('/insert_llm', response_model=QuestionResponse)
async def insert_llm(request: QuestionLLMRequest) -> QuestionResponse:
    """Generate questions using LLM and seeds.

    Process:
    1. Select seeds using specified mode (thompson/lru)
    2. Generate questions using LLM
    3. Embed generated questions
    4. Insert as raw questions
    5. Deduplicate against existing questions
    6. Track seed usage statistics

    Args:
        request: Question generation request with num_seeds and mode

    Returns:
        QuestionResponse with statistics and new question IDs

    """
    logger.info(
        f'Received LLM question generation request: num_seeds={request.num_seeds}, '
        f'questions_per_seed={request.questions_per_seed}, mode={request.mode}',
    )

    try:
        config = get_config()
        result = await insert_llm_questions(
            num_seeds=request.num_seeds,
            questions_per_seed=request.questions_per_seed,
            mode=request.mode,
            config=config,
        )

        logger.info(f'LLM question generation successful: {result}')
        return QuestionResponse(success=True, result=result)

    except Exception as exc:
        logger.error(f'LLM question generation failed: {exc}', exc_info=True)
        return QuestionResponse(
            success=False,
            error=str(exc),
        )
