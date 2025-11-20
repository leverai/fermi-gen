"""API endpoints for composite workflows (question + answer)."""

import logging

from fastapi import APIRouter

from app.config import get_config
from app.schemas.requests import InsertLiteralRequest, InsertLLMRequest
from app.schemas.responses import CompositeResponse
from app.services.composite_service import run_literal_workflow, run_llm_workflow

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post('/insert_llm', response_model=CompositeResponse)
async def insert_llm(request: InsertLLMRequest) -> CompositeResponse:
    """Generate questions via LLM, answer, enrich, and refresh view.

    Args:
        request: Request with num_seeds and mode

    Returns:
        CompositeResponse with workflow results

    """
    logger.info(
        f'Received composite LLM request: num_seeds={request.num_seeds}, '
        f'mode={request.mode}, questions_per_seed={request.questions_per_seed}',
    )

    try:
        config = get_config()
        result = await run_llm_workflow(
            num_seeds=request.num_seeds,
            questions_per_seed=request.questions_per_seed,
            mode=request.mode,
            config=config,
        )

        return CompositeResponse(
            success=result.success,
            question_result=result.question_result,
            answer_result=result.answer_result,
            enrichment_result=result.enrichment_result,
            error=result.error,
        )

    except Exception as exc:
        logger.error(f'Composite LLM workflow failed: {exc}', exc_info=True)
        return CompositeResponse(success=False, error=str(exc))


@router.post('/insert_literal', response_model=CompositeResponse)
async def insert_literal(request: InsertLiteralRequest) -> CompositeResponse:
    """Insert literal questions, answer, enrich, and refresh view.

    Args:
        request: Request with list of question texts

    Returns:
        CompositeResponse with workflow results

    """
    logger.info(
        f'Received composite literal request for {len(request.questions)} questions',
    )

    try:
        config = get_config()
        result = await run_literal_workflow(
            question_texts=request.questions,
            provider=request.provider,
            config=config,
        )

        return CompositeResponse(
            success=result.success,
            question_result=result.question_result,
            answer_result=result.answer_result,
            enrichment_result=result.enrichment_result,
            error=result.error,
        )

    except Exception as exc:
        logger.error(f'Composite literal workflow failed: {exc}', exc_info=True)
        return CompositeResponse(success=False, error=str(exc))
