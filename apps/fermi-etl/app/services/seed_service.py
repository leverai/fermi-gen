"""Service layer for seed insertion operations."""

import logging

from fermi_core.op.embed import aget_embeddings_clean_3small
from fermi_core.utils import utcnow_naive
from fermi_db import DatabaseClient
from fermi_db.models import Seed
from fermi_db.session import session_context
from pydantic import BaseModel

from app.core.validation import validate_seed

logger = logging.getLogger(__name__)


class SeedInsertionResult(BaseModel):
    """Result of a seed insertion operation."""

    original_text: str
    preprocessed_text: str
    inserted: bool
    seed_id: int | None = None
    reason: str | None = None  # Reason for rejection if not inserted


class SeedBatchResult(BaseModel):
    """Result of a batch seed insertion operation."""

    total_attempted: int
    total_inserted: int
    total_rejected: int
    insertion_rate: float
    results: list[SeedInsertionResult]


async def insert_seed(
    seed_text: str,
    db_client: DatabaseClient,
    similarity_threshold: float,
) -> SeedInsertionResult:
    """Process and insert a single seed if it's unique.

    Args:
        seed_text: The raw seed text to process
        db_client: Database client for operations
        similarity_threshold: Similarity threshold for seed uniqueness

    Returns:
        SeedInsertionResult with details of the operation

    """
    # Preprocess the seed
    preprocessed = seed_text.strip()

    # Validate the preprocessed seed
    try:
        preprocessed = validate_seed(seed_text=preprocessed)
    except AssertionError as exc:
        logger.info(
            f'Seed rejected (validation failed): "{seed_text}" -> '
            f'"{preprocessed}". Reason: {exc}',
        )
        return SeedInsertionResult(
            original_text=seed_text,
            preprocessed_text=preprocessed,
            inserted=False,
            reason=str(exc),
        )

    # Generate embedding
    embedding = (await aget_embeddings_clean_3small([preprocessed]))[0]

    # Create seed object
    seed = Seed(
        seed=preprocessed,
        embedding=embedding,
        created_at=utcnow_naive(),
    )

    # Try to insert (will check for similarity)
    seed_id = await db_client.seeds.insert_unique_seed(
        seed,
        threshold=similarity_threshold,
    )

    if seed_id is None:
        # Too similar to existing seed
        logger.info(
            f'Seed rejected (too similar): "{seed_text}" -> "{preprocessed}"',
        )
        return SeedInsertionResult(
            original_text=seed_text,
            preprocessed_text=preprocessed,
            inserted=False,
            reason=(
                f'Too similar to existing seed (threshold: {similarity_threshold})'
            ),
        )

    # Successfully inserted
    logger.info(
        f'Seed inserted successfully: "{seed_text}" -> "{preprocessed}" '
        f'(ID: {seed_id})',
    )
    return SeedInsertionResult(
        original_text=seed_text,
        preprocessed_text=preprocessed,
        inserted=True,
        seed_id=seed_id,
    )


async def insert_seeds(
    seed_texts: list[str],
    similarity_threshold: float,
) -> SeedBatchResult:
    """Process and insert a batch of seeds.

    Args:
        seed_texts: List of raw seed texts to process
        similarity_threshold: Similarity threshold for seed uniqueness

    Returns:
        SeedBatchResult with statistics and individual results

    """
    n_seeds = len(seed_texts)
    logger.info(f'Starting batch seed insertion for {n_seeds} seeds...')

    results = []
    inserted_count = 0

    # Get database session
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Remove duplicates
        seed_texts_unique = list[str](
            {seed_text.strip().lower() for seed_text in seed_texts},
        )
        n_seeds_unique = len(seed_texts_unique)
        logger.info(f'Removed {n_seeds - n_seeds_unique} literal duplicates.')

        # Insert the seeds
        for seed_text in seed_texts_unique:
            result = await insert_seed(
                seed_text=seed_text,
                db_client=db_client,
                similarity_threshold=similarity_threshold,
            )
            results.append(result)
            if result.inserted:
                inserted_count += 1

        total_attempted = n_seeds_unique
        total_rejected = total_attempted - inserted_count
        insertion_rate = (
            inserted_count / total_attempted if total_attempted > 0 else 0.0
        )

        logger.info(
            f'Batch insertion complete: {total_attempted} attempted, '
            f'{inserted_count} inserted, {total_rejected} rejected '
            f'(insertion rate: {insertion_rate:.2%})',
        )

        return SeedBatchResult(
            total_attempted=total_attempted,
            total_inserted=inserted_count,
            total_rejected=total_rejected,
            insertion_rate=insertion_rate,
            results=results,
        )
