"""Composite service for end-to-end workflows."""

import logging
import traceback
from dataclasses import dataclass
from typing import Literal

from app.config import ETLConfig
from app.services.answer_service import AnswerResult, answer_questions
from app.services.enrichment_service import (
    EnrichmentResult,
    enrich_categories,
    enrich_difficulties,
    sync_fermi_table,
)
from app.services.llm_answer_service import (
    LLMAnswerResult,
    gemini_flash_answer_questions,
    llm_answer_questions,
)
from app.services.question_service import (
    QuestionBatchResult,
    insert_literal_questions,
    insert_llm_questions,
)

logger = logging.getLogger(__name__)


@dataclass
class CompositeResult:
    """Result of a composite workflow."""

    success: bool
    question_result: QuestionBatchResult | None = None
    answer_result: AnswerResult | None = None
    enrichment_result: EnrichmentResult | None = None
    llm_answer_results: list[LLMAnswerResult] | None = None
    error: str | None = None


async def _run_answer_workflow(
    question_result: QuestionBatchResult,
    config: ETLConfig,
) -> CompositeResult:
    # Step 2: Answer questions
    logger.info(
        f'Step 2: Answering {len(question_result.new_question_ids)} questions...',
    )
    answer_result = await answer_questions(
        question_ids=question_result.new_question_ids,
        config=config,
    )

    if not answer_result.questions_answered:
        logger.error('Answer generation failed')
        return CompositeResult(
            success=False,
            question_result=question_result,
            answer_result=answer_result,
            error='Answer generation failed',
        )

    # Step 3: Enrich questions
    # Step 3.1: Enrich categories
    logger.info('Step 3.1: Enriching categories of newly answered questions...')
    try:
        category_result = await enrich_categories(
            limit=answer_result.questions_answered,
            config=config,
        )
    except Exception:
        logger.exception('Enrichment failed')
        return CompositeResult(
            success=False,
            question_result=question_result,
            answer_result=answer_result,
            error=traceback.format_exc(),
        )
    # Step 3.2: Enrich difficulties
    logger.info('Step 3.2: Enriching difficulties of newly answered questions...')
    try:
        difficulty_result = await enrich_difficulties(
            limit=answer_result.questions_answered,
            config=config,
        )
    except Exception:
        logger.exception('Enrichment failed')
        return CompositeResult(
            success=False,
            question_result=question_result,
            answer_result=answer_result,
            error=traceback.format_exc(),
        )

    # Step 4: LLM answer questions with all configured models
    logger.info('Step 4: LLM answering newly enriched questions...')
    llm_answer_results: list[LLMAnswerResult] = []
    for model in config.llm_answer_models:
        try:
            llm_result = await llm_answer_questions(
                model=model,
                limit=answer_result.questions_answered,
                config=config,
            )
            llm_answer_results.append(llm_result)
        except Exception:
            logger.exception(f'LLM answering failed for model {model}')
            # Continue with other models even if one fails

    # Step 4.5: Gemini Flash answer questions (5 models)
    logger.info('Step 4.5: Gemini Flash answering newly enriched questions...')
    try:
        gemini_result = await gemini_flash_answer_questions(
            limit=answer_result.questions_answered,
            config=config,
        )
        llm_answer_results.append(gemini_result)
    except Exception:
        logger.exception('Gemini Flash answering failed')
        # Continue even if Gemini Flash fails

    # Step 5: Sync fermi table with new questions
    await sync_fermi_table()

    # Combine enrichment results
    # Note: WE assume that both category and difficulty enrich the same questions,
    # so we use max() to avoid double-counting unique questions
    combined_enrichment = EnrichmentResult(
        enriched=max(category_result.enriched, difficulty_result.enriched),
        skipped=max(category_result.skipped, difficulty_result.skipped),
        details={
            'category': category_result.details,
            'difficulty': difficulty_result.details,
        },
    )
    logger.info('Composite workflow completed')
    return CompositeResult(
        success=True,
        question_result=question_result,
        answer_result=answer_result,
        enrichment_result=combined_enrichment,
        llm_answer_results=llm_answer_results if llm_answer_results else None,
    )


async def run_literal_workflow(
    question_texts: list[str],
    provider: Literal['human', 'other'],
    config: ETLConfig,
) -> CompositeResult:
    """Run complete literal workflow: insert → answer → enrich → refresh.

    Args:
        question_texts: List of question texts to insert
        provider: Provider of the questions
        config: Application configuration

    Returns:
        CompositeResult with all workflow results

    """
    # Step 1: Insert questions
    logger.info('Step 1: Inserting literal questions...')
    question_result = await insert_literal_questions(
        question_texts=question_texts,
        provider=provider,
        config=config,
    )

    if not question_result.new_question_ids:
        logger.info('No new questions inserted, workflow complete')
        return CompositeResult(
            success=True,
            question_result=question_result,
            error='No new questions inserted',
        )

    # Step 2: Answer and enrich questions
    composite_result = await _run_answer_workflow(question_result, config)
    logger.info('Composite result: %s', composite_result)
    return composite_result


async def run_llm_workflow(
    num_seeds: int,
    questions_per_seed: int,
    mode: Literal['thompson', 'lru'],
    config: ETLConfig,
) -> CompositeResult:
    """Run complete LLM workflow: generate → answer → enrich → refresh.

    Args:
        num_seeds: Number of seeds to use
        questions_per_seed: Questions to generate per seed
        mode: Seed selection mode
        config: Application configuration

    Returns:
        CompositeResult with all workflow results

    """
    # Step 1: Generate questions
    logger.info('Step 1: Generating questions via LLM...')
    question_result = await insert_llm_questions(
        num_seeds=num_seeds,
        questions_per_seed=questions_per_seed,
        mode=mode,
        config=config,
    )

    if not question_result.new_question_ids:
        logger.info('No new questions generated, workflow complete')
        return CompositeResult(
            success=True,
            question_result=question_result,
            error='No new questions generated',
        )

    # Step 2: Answer and enrich questions
    return await _run_answer_workflow(question_result, config)
