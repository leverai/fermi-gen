"""Semantic deduplication for generated questions."""

import logging

from fermi_db import DatabaseClient
from fermi_db.models import FermiQuestion

logger = logging.getLogger(__name__)


async def insert_unique_pending_questions(
    db_client: DatabaseClient,
    threshold: float = 0.85,
) -> list[int]:
    """Insert unique pending raw questions into the database.

    Args:
        db_client: Database client instance
        threshold: Cosine distance threshold for similarity (default 0.85)

    Returns:
        List of new question IDs that were inserted

    """
    # Fetch all pending raw questions
    pending_questions = await db_client.raw_questions.get_pending_raw_questions()

    if not pending_questions:
        logger.info('No pending questions to deduplicate')
        return []

    logger.info(f'Deduplicating {len(pending_questions)} pending questions...')

    unique_questions: list[FermiQuestion] = []
    duplicate_mappings = []
    raw_to_unique_map = {}  # Map raw_q.id -> new question for later status updates
    new_question_ids: list[int] = []

    # Step 1: Check all questions for similarity and collect unique ones
    for raw_q in pending_questions:
        # Check similarity against existing unique questions
        similar = await db_client.questions.find_similar_questions(
            embedding=raw_q.embedding,
            threshold=threshold,
        )

        if similar:
            # Found similar question - record for later status update
            canonical_question, distance = similar[0]
            duplicate_mappings.append((raw_q.id, canonical_question.id))  # type: ignore
            logger.debug(
                f'Question "{raw_q.text[:50]}..." marked as duplicate of'
                f'"{canonical_question.text[:50]}..."'
                f'(distance={distance:.3f})',
            )
        else:
            # No similar question found - add to bulk insert list
            new_question = FermiQuestion(
                seed_id=raw_q.seed_id,
                text=raw_q.text,
                embedding=raw_q.embedding,
                source=raw_q.source,
                created_at=raw_q.created_at,
            )
            unique_questions.append(new_question)
            raw_to_unique_map[raw_q.id] = len(unique_questions) - 1  # type: ignore
            logger.debug(f'Question "{raw_q.text[:50]}..." marked as unique')

    # Step 2: Bulk insert all unique questions at once
    if unique_questions:
        question_ids = await db_client.questions.bulk_insert_unique_questions(
            unique_questions,
        )
        new_question_ids = question_ids  # Store for return value
        logger.info(f'Bulk inserted {len(question_ids)} unique questions')

        # Step 3: Update status for unique questions
        for raw_q_id, idx in raw_to_unique_map.items():
            await db_client.raw_questions.update_dedup_status(
                question_id=raw_q_id,
                status='unique',
                canonical_id=question_ids[idx],
            )

    # Step 4: Update status for duplicate questions
    for raw_q_id, canonical_id in duplicate_mappings:
        await db_client.raw_questions.update_dedup_status(
            question_id=raw_q_id,
            status='duplicate',
            canonical_id=canonical_id,
        )

    unique_count = len(unique_questions)
    duplicate_count = len(duplicate_mappings)

    logger.info(
        f'Deduplication complete: {unique_count} unique, {duplicate_count} duplicates',
    )
    return new_question_ids
