"""LLM answers API endpoints."""

import logging

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.config import get_config
from app.services.llm_answer_service import (
    LLMAnswerResult,
    answer_gpt,
)
from app.services.llm_answer_service import (
    answer_gemini_flash as _answer_gemini_flash,
)

logger = logging.getLogger(__name__)

router = APIRouter()


class LLMAnswerRequest(BaseModel):
    """Request body for LLM answering endpoints."""

    num_questions: int = 50


class GeminiFlashRequest(BaseModel):
    """Request body for Gemini Flash answering endpoint."""

    num_questions: int = 50
    model_name: str = 'gemini-2.5-flash-lite'
    model_provider: str = 'google-vertexai'
    temperature: float = Field(default=0.2, le=0.2)


@router.post('/gpt-5.1', response_model=LLMAnswerResult)
async def answer_gpt51(request: LLMAnswerRequest) -> LLMAnswerResult:
    """Answer questions using gpt-5.1 model."""
    logger.info(f'LLM answering {request.num_questions} questions with gpt-5.1')
    return await answer_gpt(model='gpt-5.1', limit=request.num_questions)


@router.post('/gpt-5-mini', response_model=LLMAnswerResult)
async def answer_gpt5_mini(request: LLMAnswerRequest) -> LLMAnswerResult:
    """Answer questions using gpt-5-mini model."""
    logger.info(f'LLM answering {request.num_questions} questions with gpt-5-mini')
    return await answer_gpt(model='gpt-5-mini', limit=request.num_questions)


@router.post('/gpt-5-nano', response_model=LLMAnswerResult)
async def answer_gpt5_nano(request: LLMAnswerRequest) -> LLMAnswerResult:
    """Answer questions using gpt-5-nano model."""
    logger.info(f'LLM answering {request.num_questions} questions with gpt-5-nano')
    return await answer_gpt(model='gpt-5-nano', limit=request.num_questions)


@router.post('/gemini-flash', response_model=LLMAnswerResult)
async def answer_gemini_flash(request: GeminiFlashRequest) -> LLMAnswerResult:
    """Answer questions with 5 Gemini Flash instances (atomic upload).

    Each question gets 5 Gemini answers. All 5 must succeed for any to be stored.
    Model settings (name, provider, temperature) can be configured per request.
    """
    logger.info(
        f'LLM answering {request.num_questions} questions with '
        f'Gemini Flash ({request.model_name}, temp={request.temperature})',
    )
    return await _answer_gemini_flash(
        limit=request.num_questions,
        model=request.model_name,
        model_provider=request.model_provider,
        temperature=request.temperature,
    )


@router.post('/all', response_model=list[LLMAnswerResult])
async def answer_all_models(request: GeminiFlashRequest) -> list[LLMAnswerResult]:
    """Answer questions using all LLM models (GPT and Gemini Flash)."""
    logger.info(f'LLM answering {request.num_questions} questions with all models')
    config = get_config()
    results = []
    # GPT models first
    for model in config.gpt_answer_models:
        result = await answer_gpt(model=model, limit=request.num_questions)
        results.append(result)
    # Then Gemini Flash
    gemini_result = await _answer_gemini_flash(
        limit=request.num_questions,
        model=request.model_name,
        model_provider=request.model_provider,
        temperature=request.temperature,
    )
    results.append(gemini_result)
    return results
