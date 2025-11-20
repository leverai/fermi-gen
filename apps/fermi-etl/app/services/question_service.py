"""Service layer for question generation and insertion operations."""

import logging
from typing import Any, Literal

from fermi_core.op.ask import aask_batch
from fermi_core.op.embed import aget_embeddings_clean_3small
from fermi_db import DatabaseClient
from fermi_db.models import RawQuestion
from fermi_db.session import session_context
from pydantic import BaseModel

from app.config import ETLConfig
from app.core.deduplication import insert_unique_pending_questions
from app.core.seed_selection import select_seeds_lru, select_seeds_thompson
from app.core.validation import validate_question
from app.version import __version__

logger = logging.getLogger(__name__)


class QuestionBatchResult(BaseModel):
    """Result of a question generation/insertion operation."""

    mode: str | None = None  # 'thompson', 'lru', or 'literal'
    seeds_used: int = 0
    questions_requested: int
    questions_generated: int
    questions_yielded: int
    yield_rate: float
    new_question_ids: list[int]  # IDs of newly inserted unique questions


def _create_llm_source_metadata(
    seed: str | None = None,
    model: str | None = None,
    model_provider: str = 'openai',
) -> dict[str, Any]:
    """Create source metadata for an llm-generated question."""
    metadata: dict[str, Any] = {
        'model_provider': model_provider,
        'generator': 'fermi-etl',
        'pipeline_version': __version__,
    }

    if seed is not None:
        metadata['seed'] = seed
    if model is not None:
        metadata['model'] = model

    return metadata


def _create_literal_source_metadata(provider: str) -> dict[str, Any]:
    """Create source metadata for a literal provider."""
    return {
        'provider': provider,
        'generator': 'fermi-etl',
        'pipeline_version': __version__,
    }


async def insert_llm_questions(
    num_seeds: int = 5,
    questions_per_seed: int = 20,
    mode: Literal['thompson', 'lru'] = 'thompson',
    config: ETLConfig | None = None,
) -> QuestionBatchResult:
    """Generate questions from seeds using LLM.

    Flow: seed selection → LLM generation → embedding → raw insertion → dedup

    Args:
        num_seeds: Number of seeds to use for generation
        questions_per_seed: Number of questions to generate per seed
        mode: Seed selection mode ('thompson' or 'lru')
        config: ETL configuration (if None, load from env)

    Returns:
        QuestionBatchResult with statistics and new question IDs

    Raises:
        ValueError: If mode is invalid

    """
    if config is None:
        from app.config import get_config

        config = get_config()

    if mode not in ['thompson', 'lru']:
        raise ValueError(f"Invalid mode '{mode}'. Must be 'thompson' or 'lru'")

    logger.info(
        f'Starting question generation: mode={mode}, num_seeds={num_seeds}, '
        f'questions_per_seed={questions_per_seed}',
    )

    total_requested = 0
    total_generated = 0
    seed_to_usage_id: dict[int, int] = {}  # Map seed_id -> seed usage_id

    # Get database session
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Step 1: Select seeds
        logger.info(f'Selecting {num_seeds} seeds using {mode} mode...')
        if mode == 'thompson':
            seed_ids = await select_seeds_thompson(db_client, num_seeds)
        else:
            seed_ids = await select_seeds_lru(db_client, num_seeds)

        if not seed_ids:
            logger.warning('No seeds available for generation')
            return QuestionBatchResult(
                mode=mode,
                seeds_used=0,
                questions_requested=0,
                questions_generated=0,
                questions_yielded=0,
                yield_rate=0.0,
                new_question_ids=[],
            )

        logger.info(f'Selected {len(seed_ids)} seeds: {seed_ids}')

        # Step 2: Fetch seed IDs and text only (no embeddings for performance)
        logger.info('Fetching seed details...')
        seeds = await db_client.seeds.get_seeds_light_by_ids(seed_ids)
        if not seeds:
            raise RuntimeError('Seed ids returned do not exist in the database')

        if len(seeds) < len(seed_ids):
            logger.error(
                f'{len(seed_ids) - len(seeds)} seed ids returned do not exist in the '
                'database. This is likely a bug somewhere.',
            )

        # Step 3: Generate questions for all seeds in parallel (batch mode)
        logger.info(f'Generating questions for {len(seeds)} seeds in batch...')
        batches = await aask_batch(
            seeds=[seed.seed for seed in seeds],
            num_questions=questions_per_seed,
            model=config.question_generation_model,
            model_provider=config.question_generation_model_provider,
        )

        # Step 4: Process all responses and create raw questions
        logger.info('Processing generated questions and creating embeddings...')
        all_raw_questions = []
        for seed, batch in zip(seeds, batches, strict=True):
            # Check if this batch failed
            if isinstance(batch, BaseException):
                logger.error(
                    f'Failed to generate questions for seed "{seed.seed}":\n{batch}',
                )
                continue

            # Successful batch
            questions = batch.questions
            logger.info(f'Generated {len(questions)} questions for seed "{seed.seed}"')

            # Record usage
            usage_id = await db_client.seeds_usage.record_usage(
                seed_id=seed.id,  # type: ignore
                requested=questions_per_seed,
                generated=len(questions),
            )
            seed_to_usage_id[seed.id] = usage_id  # type: ignore

            # Embed questions
            embeddings = await aget_embeddings_clean_3small([q.text for q in questions])

            # Create raw question records
            for question, embedding in zip(questions, embeddings, strict=True):
                source = _create_llm_source_metadata(
                    seed=seed.seed,
                    model=config.question_generation_model,
                    model_provider=config.question_generation_model_provider,
                )
                raw_q = RawQuestion(
                    seed_id=seed.id,  # type: ignore
                    text=question.text,
                    embedding=embedding,
                    source=source,
                    dedup_status='pending',
                )
                all_raw_questions.append(raw_q)

        # Step 5: Bulk insert all raw questions at once
        logger.info(f'Bulk inserting {len(all_raw_questions)} raw questions...')
        await db_client.raw_questions.bulk_insert_raw_questions(all_raw_questions)

        total_requested = len(seed_ids) * questions_per_seed
        total_generated = len(all_raw_questions)

        # Step 6: Deduplicate pending raw questions and insert the unique ones
        logger.info('Starting deduplication...')
        new_question_ids = await insert_unique_pending_questions(
            db_client,
            threshold=config.question_similarity_threshold,
        )
        total_yielded = len(new_question_ids)

        # Step 7: Update usage records with actual yielded counts per seed
        logger.info('Computing yield counts per seed...')
        yield_counts = await db_client.raw_questions.get_yield_counts_by_seed(
            seed_ids=list[int](seed_to_usage_id.keys()),
        )

        for seed_id, usage_id in seed_to_usage_id.items():
            # Get actual yield for this seed (0 if no unique questions)
            yielded = yield_counts.get(seed_id, 0)
            await db_client.seeds_usage.update_yielded(usage_id, yielded)

        yield_rate = total_yielded / total_requested if total_requested > 0 else 0.0

        logger.info(
            f'Question generation complete: {total_requested} requested, '
            f'{total_generated} generated, {total_yielded} yielded '
            f'(yield rate: {yield_rate:.2%})',
        )

        return QuestionBatchResult(
            mode=mode,
            seeds_used=len(seed_ids),
            questions_requested=total_requested,
            questions_generated=total_generated,
            questions_yielded=total_yielded,
            yield_rate=yield_rate,
            new_question_ids=new_question_ids,
        )

    # Should never reach here due to async generator
    raise RuntimeError('Failed to get database session')


async def insert_literal_questions(
    question_texts: list[str],
    provider: Literal['human', 'other'],
    config: ETLConfig | None = None,
) -> QuestionBatchResult:
    """Insert user-provided question texts directly.

    Flow: preprocess text → validate → embed → create RawQuestion objects →
          bulk insert raw → dedup

    Args:
        question_texts: List of question texts to insert
        provider: The provider of the literal questions ('human' or 'other')
        config: ETL configuration (if None, load from env)

    Returns:
        QuestionBatchResult with statistics and new question IDs

    """
    if config is None:
        from app.config import get_config

        config = get_config()

    logger.info(
        f'Starting literal question insertion for {len(question_texts)} questions...',
    )

    # Get database session
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Step 1: Preprocess and validate questions
        valid_questions = []
        for question_text in question_texts:
            preprocessed = question_text.strip()
            is_valid, error_msg = validate_question(preprocessed)

            if not is_valid:
                logger.warning(
                    f'Question rejected (validation failed): "{question_text[:50]}..." '
                    f'Reason: {error_msg}',
                )
                continue

            valid_questions.append(preprocessed)

        if not valid_questions:
            logger.warning('No valid questions to insert after validation')
            return QuestionBatchResult(
                mode='literal',
                questions_requested=len(question_texts),
                questions_generated=0,
                questions_yielded=0,
                yield_rate=0.0,
                new_question_ids=[],
            )

        logger.info(f'{len(valid_questions)} questions passed validation')

        # Step 2: Generate embeddings
        logger.info('Generating embeddings for questions...')
        embeddings = await aget_embeddings_clean_3small(valid_questions)

        # Step 3: Create raw question records
        logger.info('Creating raw question records...')
        all_raw_questions = []
        source = _create_literal_source_metadata(provider=provider)

        for question_text, embedding in zip(valid_questions, embeddings, strict=True):
            raw_q = RawQuestion(
                seed_id=None,  # No seed for literal questions
                text=question_text,
                embedding=embedding,
                source=source,
                dedup_status='pending',
            )
            all_raw_questions.append(raw_q)

        # Step 4: Bulk insert all raw questions
        logger.info(f'Bulk inserting {len(all_raw_questions)} raw questions...')
        await db_client.raw_questions.bulk_insert_raw_questions(all_raw_questions)

        # Step 5: Deduplicate questions
        logger.info('Starting deduplication...')
        new_question_ids = await insert_unique_pending_questions(
            db_client,
            threshold=config.question_similarity_threshold,
        )
        total_yielded = len(new_question_ids)

        yield_rate = total_yielded / len(valid_questions) if valid_questions else 0.0

        logger.info(
            f'Literal question insertion complete: {len(question_texts)} requested, '
            f'{len(valid_questions)} validated, {total_yielded} yielded '
            f'(yield rate: {yield_rate:.2%})',
        )

        return QuestionBatchResult(
            mode='literal',
            questions_requested=len(question_texts),
            questions_generated=len(valid_questions),
            questions_yielded=total_yielded,
            yield_rate=yield_rate,
            new_question_ids=new_question_ids,
        )
