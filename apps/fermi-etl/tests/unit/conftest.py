"""Unit test fixtures for fermi-etl.

Provides mocks and sample data for testing business logic without external dependencies.
"""

from datetime import UTC, datetime
from typing import TYPE_CHECKING
from unittest.mock import AsyncMock, MagicMock

import numpy as np
import pytest
from fermi_db.models import FermiQuestion, RawQuestion

if TYPE_CHECKING:
    import pytest


@pytest.fixture
def mock_db_client() -> MagicMock:
    """Provide a fully mocked DatabaseClient with all repository methods.

    Returns:
        MagicMock: Mock DatabaseClient with mocked repository methods

    """
    mock_client = MagicMock()

    # Mock seeds repository
    mock_client.seeds = MagicMock()
    mock_client.seeds.insert_unique_seed = AsyncMock(return_value=1)
    mock_client.seeds.get_seeds_light_by_ids = AsyncMock(return_value=[])

    # Mock seeds_usage repository
    mock_client.seeds_usage = MagicMock()
    mock_client.seeds_usage.get_aggregated_stats = AsyncMock(return_value=[])
    mock_client.seeds_usage.get_least_recently_used_seeds = AsyncMock(return_value=[])
    mock_client.seeds_usage.record_usage = AsyncMock(return_value=1)
    mock_client.seeds_usage.update_yielded = AsyncMock(return_value=None)

    # Mock questions repository
    mock_client.questions = MagicMock()
    mock_client.questions.find_similar_questions = AsyncMock(return_value=[])
    mock_client.questions.bulk_insert_unique_questions = AsyncMock(return_value=[])

    # Mock raw_questions repository
    mock_client.raw_questions = MagicMock()
    mock_client.raw_questions.get_pending_raw_questions = AsyncMock(return_value=[])
    mock_client.raw_questions.bulk_insert_raw_questions = AsyncMock(return_value=None)
    mock_client.raw_questions.update_dedup_status = AsyncMock(return_value=None)
    mock_client.raw_questions.get_yield_counts_by_seed = AsyncMock(return_value={})

    return mock_client


@pytest.fixture
def mock_embeddings(monkeypatch: 'pytest.MonkeyPatch') -> AsyncMock:
    """Patch embedding function to return deterministic vectors.

    This fixture patches aget_embeddings_clean_3small to return fixed vectors
    instead of calling the actual OpenAI API.

    Returns:
        AsyncMock: Mock that returns deterministic embedding vectors

    """

    async def mock_get_embeddings(texts: list[str]) -> list[list[float]]:
        """Return deterministic embeddings based on text content."""
        return [
            np.random.RandomState(hash(text) % (2**32)).rand(1536).tolist()
            for text in texts
        ]

    mock = AsyncMock(side_effect=mock_get_embeddings)
    monkeypatch.setattr('app.core.deduplication.aget_embeddings_clean_3small', mock)
    monkeypatch.setattr('app.services.seed_service.aget_embeddings_clean_3small', mock)
    monkeypatch.setattr(
        'app.services.question_service.aget_embeddings_clean_3small',
        mock,
    )
    return mock


@pytest.fixture
def sample_seed_stats() -> list:
    """Provide sample seed statistics for Thompson/LRU selection tests.

    Returns:
        list: List of SeedStats-like objects with various alpha/beta values

    """
    # Mock SeedStats objects with different success rates
    seed_stat_class = type('SeedStat', (), {})

    # High success seed (alpha=10, beta=2) - 10 successes, 2 failures
    high_success = seed_stat_class()
    high_success.seed_id = 1  # type: ignore[attr-defined]
    high_success.alpha = 10  # type: ignore[attr-defined]
    high_success.beta = 2  # type: ignore[attr-defined]

    # Medium success seed (alpha=5, beta=5) - 5 successes, 5 failures
    medium_success = seed_stat_class()
    medium_success.seed_id = 2  # type: ignore[attr-defined]
    medium_success.alpha = 5  # type: ignore[attr-defined]
    medium_success.beta = 5  # type: ignore[attr-defined]

    # Low success seed (alpha=2, beta=10) - 2 successes, 10 failures
    low_success = seed_stat_class()
    low_success.seed_id = 3  # type: ignore[attr-defined]
    low_success.alpha = 2  # type: ignore[attr-defined]
    low_success.beta = 10  # type: ignore[attr-defined]

    # New seed with uniform prior (alpha=1, beta=1) - no history
    new_seed = seed_stat_class()
    new_seed.seed_id = 4  # type: ignore[attr-defined]
    new_seed.alpha = 1  # type: ignore[attr-defined]
    new_seed.beta = 1  # type: ignore[attr-defined]

    return [high_success, medium_success, low_success, new_seed]


@pytest.fixture
def sample_raw_questions() -> list[RawQuestion]:
    """Provide sample raw questions for deduplication tests.

    Returns:
        list: List of RawQuestion objects with embeddings

    """
    now = datetime.now(UTC).replace(tzinfo=None)

    questions = []
    for i in range(3):
        q = RawQuestion(
            id=i + 1,
            seed_id=1,
            text=f'How many test questions are there in scenario {i}?',
            embedding=np.random.rand(1536).tolist(),
            source={'provider': 'test'},
            dedup_status='pending',
            created_at=now,
        )
        questions.append(q)

    return questions


@pytest.fixture
def sample_fermi_questions() -> list[FermiQuestion]:
    """Provide sample FermiQuestion objects for similarity checks.

    Returns:
        list: List of FermiQuestion objects with embeddings

    """
    now = datetime.now(UTC).replace(tzinfo=None)

    questions = []
    for i in range(2):
        q = FermiQuestion(
            id=i + 100,  # Different IDs from raw questions
            seed_id=1,
            text=f'How many existing questions are there in category {i}?',
            embedding=np.random.rand(1536).tolist(),
            source={'provider': 'test'},
            created_at=now,
        )
        questions.append(q)

    return questions
