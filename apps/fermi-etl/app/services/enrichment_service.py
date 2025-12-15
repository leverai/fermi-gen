"""Enrichment service for categorizing and assessing difficulty of questions."""

import logging
from typing import Any

from fermi_core.op.categorize import acategorize_batch
from fermi_core.op.difficulty import adifficulty_batch
from fermi_db.dal import DatabaseClient
from fermi_db.schemas import QuestionCategory, QuestionDifficulty
from fermi_db.session import session_context
from pydantic import BaseModel

from app.config import ETLConfig

logger = logging.getLogger(__name__)


class EnrichmentResult(BaseModel):
    """Result of an enrichment operation."""

    enriched: int
    skipped: int
    details: dict[str, Any] | None = None


async def enrich_categories(
    limit: int,
    config: ETLConfig,
) -> EnrichmentResult:
    """Enrich questions with categories using LLM classification.

    Args:
        limit: Maximum number of questions to enrich
        config: Application configuration

    Returns:
        EnrichmentResult with statistics

    """
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Get questions needing category
        questions_data = await db_client.enrichment.get_questions_needing_category(
            limit,
        )

        if not questions_data:
            logger.info('No questions need category enrichment')
            return EnrichmentResult(
                enriched=0,
                skipped=0,
                details={'message': 'No questions need categorization'},
            )

        question_ids = [qid for qid, _ in questions_data]
        question_texts = [text for _, text in questions_data]

        logger.info(f'Enriching categories for {len(question_texts)} questions')

        # Batch categorize using langchain
        results = await acategorize_batch(
            questions=question_texts,
            model=config.category_model,
            model_provider=config.category_model_provider,
            temperature=0.5,
            # service_tier='flex',
        )

        # Process results and prepare updates
        updates: list[tuple[int, QuestionCategory]] = []
        skipped = 0

        for question_id, result in zip(question_ids, results, strict=True):
            if isinstance(result, BaseException):
                logger.error(f'Failed to categorize question {question_id}: {result}')
                skipped += 1
                continue

            # Convert from fermi-core schema to fermi-db schema
            category = QuestionCategory(result.category)
            updates.append((question_id, category))

        # Batch update database
        if updates:
            await db_client.enrichment.batch_update_categories(updates)
            logger.info(
                f'Successfully enriched {len(updates)} questions with categories',
            )

        return EnrichmentResult(
            enriched=len(updates),
            skipped=skipped,
            details={
                'total_requested': len(question_texts),
                'successful': len(updates),
                'failed': skipped,
            },
        )


async def enrich_difficulties(
    limit: int,
    config: ETLConfig,
) -> EnrichmentResult:
    """Enrich questions with difficulties using LLM classification.

    Args:
        limit: Maximum number of questions to enrich
        config: Application configuration

    Returns:
        EnrichmentResult with statistics

    """
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Get questions needing difficulty
        questions_data = await db_client.enrichment.get_questions_needing_difficulty(
            limit,
        )

        if not questions_data:
            logger.info('No questions need difficulty enrichment')
            return EnrichmentResult(
                enriched=0,
                skipped=0,
                details={'message': 'No questions need difficulty assessment'},
            )

        question_ids = [qid for qid, _ in questions_data]
        question_texts = [text for _, text in questions_data]

        logger.info(f'Enriching difficulties for {len(question_texts)} questions')

        # Batch assess difficulty using langchain
        results = await adifficulty_batch(
            questions=question_texts,
            model=config.difficulty_model,
            model_provider=config.difficulty_model_provider,
            temperature=0.5,
            # service_tier='flex',
        )

        # Process results and prepare updates
        updates: list[tuple[int, QuestionDifficulty]] = []
        skipped = 0

        for question_id, result in zip(question_ids, results, strict=True):
            if isinstance(result, BaseException):
                logger.error(
                    f'Failed to assess difficulty for question {question_id}: {result}',
                )
                skipped += 1
                continue

            # Convert from fermi-core schema to fermi-db schema
            difficulty = QuestionDifficulty(result.difficulty)
            updates.append((question_id, difficulty))

        # Batch update database
        if updates:
            await db_client.enrichment.batch_update_difficulties(updates)
            logger.info(
                f'Successfully enriched {len(updates)} questions with difficulties',
            )

        return EnrichmentResult(
            enriched=len(updates),
            skipped=skipped,
            details={
                'total_requested': len(question_texts),
                'successful': len(updates),
                'failed': skipped,
            },
        )


async def sync_fermi_table() -> int:
    """Sync fermi table with newly enriched questions.

    Returns:
        Number of new questions inserted

    """
    async with session_context() as session:
        db_client = DatabaseClient(session)
        return await db_client.enrichment.sync_fermi_table()
