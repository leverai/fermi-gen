"""LLM answers API endpoints."""

import logging

from fastapi import APIRouter
from pydantic import BaseModel

from app.config import get_config
from app.services.llm_answer_service import LLMAnswerResult, llm_answer_questions

logger = logging.getLogger(__name__)

router = APIRouter()


class LLMAnswerRequest(BaseModel):
    """Request body for LLM answering endpoints."""

    num_questions: int = 50


@router.post('/gpt-5.1', response_model=LLMAnswerResult)
async def answer_gpt51(request: LLMAnswerRequest) -> LLMAnswerResult:
    """Answer questions using gpt-5.1 model."""
    logger.info(f'LLM answering {request.num_questions} questions with gpt-5.1')
    config = get_config()
    return await llm_answer_questions(
        model='gpt-5.1',
        limit=request.num_questions,
        config=config,
    )


@router.post('/gpt-5-mini', response_model=LLMAnswerResult)
async def answer_gpt5_mini(request: LLMAnswerRequest) -> LLMAnswerResult:
    """Answer questions using gpt-5-mini model."""
    logger.info(f'LLM answering {request.num_questions} questions with gpt-5-mini')
    config = get_config()
    return await llm_answer_questions(
        model='gpt-5-mini',
        limit=request.num_questions,
        config=config,
    )


@router.post('/gpt-5-nano', response_model=LLMAnswerResult)
async def answer_gpt5_nano(request: LLMAnswerRequest) -> LLMAnswerResult:
    """Answer questions using gpt-5-nano model."""
    logger.info(f'LLM answering {request.num_questions} questions with gpt-5-nano')
    config = get_config()
    return await llm_answer_questions(
        model='gpt-5-nano',
        limit=request.num_questions,
        config=config,
    )


@router.post('/all', response_model=list[LLMAnswerResult])
async def answer_all_models(request: LLMAnswerRequest) -> list[LLMAnswerResult]:
    """Answer questions using all LLM models (gpt-5.1, gpt-5-mini, gpt-5-nano)."""
    logger.info(f'LLM answering {request.num_questions} questions with all models')
    config = get_config()
    results = []
    for model in config.llm_answer_models:
        result = await llm_answer_questions(
            model=model,
            limit=request.num_questions,
            config=config,
        )
        results.append(result)
    return results
