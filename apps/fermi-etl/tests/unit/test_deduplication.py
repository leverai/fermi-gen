"""Unit tests for semantic deduplication logic."""

from typing import Any
from unittest.mock import MagicMock

import pytest

from app.core.deduplication import insert_unique_pending_questions


@pytest.mark.asyncio
async def test_insert_unique_questions_all_unique(
    mock_db_client: MagicMock,
    sample_raw_questions: list,
    sample_fermi_questions: list,
) -> None:
    """Test inserting questions when all are unique (below threshold).

    All questions should be inserted and marked as 'unique'.
    """
    # Mock pending questions
    mock_db_client.raw_questions.get_pending_raw_questions.return_value = (
        sample_raw_questions
    )

    # Mock find_similar_questions to return empty (no similar questions found)
    mock_db_client.questions.find_similar_questions.return_value = []

    # Mock bulk insert to return sequential IDs
    mock_db_client.questions.bulk_insert_unique_questions.return_value = [101, 102, 103]

    # Run deduplication
    new_question_ids = await insert_unique_pending_questions(
        mock_db_client,
        threshold=0.85,
    )

    # Verify all questions were inserted
    assert len(new_question_ids) == 3
    assert new_question_ids == [101, 102, 103]

    # Verify bulk insert was called with 3 questions
    assert mock_db_client.questions.bulk_insert_unique_questions.call_count == 1
    inserted_questions = (
        mock_db_client.questions.bulk_insert_unique_questions.call_args[0][0]
    )
    assert len(inserted_questions) == 3

    # Verify all were marked as unique
    assert mock_db_client.raw_questions.update_dedup_status.call_count == 3
    for call in mock_db_client.raw_questions.update_dedup_status.call_args_list:
        args, kwargs = call
        assert kwargs['status'] == 'unique'
        assert kwargs['canonical_id'] in [101, 102, 103]


@pytest.mark.asyncio
async def test_insert_unique_questions_all_duplicates(
    mock_db_client: MagicMock,
    sample_raw_questions: list,
    sample_fermi_questions: list,
) -> None:
    """Test when all questions are duplicates (above threshold).

    No questions should be inserted, all marked as 'duplicate'.
    """
    # Mock pending questions
    mock_db_client.raw_questions.get_pending_raw_questions.return_value = (
        sample_raw_questions
    )

    # Mock find_similar_questions to always return a similar question
    existing_question = sample_fermi_questions[0]
    mock_db_client.questions.find_similar_questions.return_value = [
        (existing_question, 0.95),  # High similarity (above threshold)
    ]

    # Run deduplication
    new_question_ids = await insert_unique_pending_questions(
        mock_db_client,
        threshold=0.85,
    )

    # Verify no questions were inserted
    assert len(new_question_ids) == 0

    # Verify bulk insert was NOT called
    assert mock_db_client.questions.bulk_insert_unique_questions.call_count == 0

    # Verify all were marked as duplicate
    assert mock_db_client.raw_questions.update_dedup_status.call_count == 3
    for call in mock_db_client.raw_questions.update_dedup_status.call_args_list:
        args, kwargs = call
        assert kwargs['status'] == 'duplicate'
        assert kwargs['canonical_id'] == existing_question.id


@pytest.mark.asyncio
async def test_insert_unique_questions_mixed_batch(
    mock_db_client: MagicMock,
    sample_raw_questions: list,
    sample_fermi_questions: list,
) -> None:
    """Test with mixed batch: some unique, some duplicates.

    Only unique questions should be inserted, duplicates rejected.
    """
    # Mock pending questions (3 total)
    mock_db_client.raw_questions.get_pending_raw_questions.return_value = (
        sample_raw_questions
    )

    existing_question = sample_fermi_questions[0]

    # Mock find_similar_questions to return similar for first question only
    async def mock_find_similar(
        embedding: list[float],
        threshold: float,
    ) -> list[Any]:
        # First question is duplicate, others are unique
        if embedding == sample_raw_questions[0].embedding:
            return [(existing_question, 0.95)]
        return []

    mock_db_client.questions.find_similar_questions.side_effect = mock_find_similar

    # Mock bulk insert to return IDs for the 2 unique questions
    mock_db_client.questions.bulk_insert_unique_questions.return_value = [102, 103]

    # Run deduplication
    new_question_ids = await insert_unique_pending_questions(
        mock_db_client,
        threshold=0.85,
    )

    # Verify only 2 unique questions were inserted
    assert len(new_question_ids) == 2
    assert new_question_ids == [102, 103]

    # Verify bulk insert was called with 2 questions
    assert mock_db_client.questions.bulk_insert_unique_questions.call_count == 1
    inserted_questions = (
        mock_db_client.questions.bulk_insert_unique_questions.call_args[0][0]
    )
    assert len(inserted_questions) == 2

    # Verify update_dedup_status called 3 times (1 duplicate + 2 unique)
    assert mock_db_client.raw_questions.update_dedup_status.call_count == 3

    # Check that first question was marked duplicate
    duplicate_calls = [
        call
        for call in mock_db_client.raw_questions.update_dedup_status.call_args_list
        if call[1]['status'] == 'duplicate'
    ]
    assert len(duplicate_calls) == 1
    assert duplicate_calls[0][1]['canonical_id'] == existing_question.id

    # Check that other questions were marked unique
    unique_calls = [
        call
        for call in mock_db_client.raw_questions.update_dedup_status.call_args_list
        if call[1]['status'] == 'unique'
    ]
    assert len(unique_calls) == 2


@pytest.mark.asyncio
async def test_insert_unique_questions_no_pending(mock_db_client: MagicMock) -> None:
    """Test when there are no pending questions to process."""
    # Mock empty pending questions
    mock_db_client.raw_questions.get_pending_raw_questions.return_value = []

    # Run deduplication
    new_question_ids = await insert_unique_pending_questions(
        mock_db_client,
        threshold=0.85,
    )

    # Verify no questions were processed
    assert len(new_question_ids) == 0

    # Verify bulk insert was NOT called
    assert mock_db_client.questions.bulk_insert_unique_questions.call_count == 0

    # Verify update_dedup_status was NOT called
    assert mock_db_client.raw_questions.update_dedup_status.call_count == 0


@pytest.mark.asyncio
async def test_insert_unique_questions_custom_threshold(
    mock_db_client: MagicMock,
    sample_raw_questions: list,
) -> None:
    """Test deduplication with custom similarity threshold."""
    # Mock pending questions
    mock_db_client.raw_questions.get_pending_raw_questions.return_value = (
        sample_raw_questions[:1]
    )

    # Mock find_similar_questions to be called with custom threshold
    mock_db_client.questions.find_similar_questions.return_value = []
    mock_db_client.questions.bulk_insert_unique_questions.return_value = [101]

    # Run deduplication with custom threshold
    custom_threshold = 0.75
    await insert_unique_pending_questions(
        mock_db_client,
        threshold=custom_threshold,
    )

    # Verify threshold was used in find_similar_questions call
    assert mock_db_client.questions.find_similar_questions.call_count == 1
    call_args = mock_db_client.questions.find_similar_questions.call_args
    assert call_args[1]['threshold'] == custom_threshold


@pytest.mark.asyncio
async def test_insert_unique_questions_preserves_metadata(
    mock_db_client: MagicMock,
    sample_raw_questions: list,
) -> None:
    """Test that question metadata is preserved during deduplication."""
    # Mock pending questions
    raw_q = sample_raw_questions[0]
    mock_db_client.raw_questions.get_pending_raw_questions.return_value = [raw_q]

    # Mock as unique
    mock_db_client.questions.find_similar_questions.return_value = []
    mock_db_client.questions.bulk_insert_unique_questions.return_value = [101]

    # Run deduplication
    await insert_unique_pending_questions(mock_db_client, threshold=0.85)

    # Verify the inserted question has correct metadata
    inserted_questions = (
        mock_db_client.questions.bulk_insert_unique_questions.call_args[0][0]
    )
    assert len(inserted_questions) == 1
    inserted_q = inserted_questions[0]

    # Check all fields are preserved
    assert inserted_q.seed_id == raw_q.seed_id
    assert inserted_q.text == raw_q.text
    assert inserted_q.embedding == raw_q.embedding
    assert inserted_q.source == raw_q.source
    assert inserted_q.created_at == raw_q.created_at
