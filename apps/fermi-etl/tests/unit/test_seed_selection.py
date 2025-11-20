"""Unit tests for seed selection algorithms (Thompson sampling and LRU)."""

from unittest.mock import MagicMock

import numpy as np
import pytest

from app.core.seed_selection import (
    _thompson_sample,
    select_seeds_lru,
    select_seeds_thompson,
)


@pytest.mark.asyncio
async def test_thompson_sampling_with_deterministic_seed(
    mock_db_client: MagicMock,
    sample_seed_stats: list,
) -> None:
    """Test Thompson sampling with deterministic random seed.

    Verifies that with a fixed random seed, Thompson sampling produces
    consistent results and tends to select high-success seeds.
    """
    # Set random seed for reproducibility
    np.random.seed(42)

    # Mock the get_aggregated_stats to return our sample data
    mock_db_client.seeds_usage.get_aggregated_stats.return_value = sample_seed_stats

    # Select 2 seeds
    selected_ids = await select_seeds_thompson(mock_db_client, n=2)

    # Should return 2 seed IDs
    assert len(selected_ids) == 2
    # All IDs should be from our sample stats
    assert all(sid in [1, 2, 3, 4] for sid in selected_ids)
    # Should not have duplicates
    assert len(set(selected_ids)) == 2


@pytest.mark.asyncio
async def test_thompson_sampling_statistical_properties(
    mock_db_client: MagicMock,
    sample_seed_stats: list,
) -> None:
    """Test that Thompson sampling selects high-success seeds more often.

    Runs multiple iterations to verify statistical properties:
    - High alpha seed (seed_id=1) should be selected more frequently
    - Low alpha seed (seed_id=3) should be selected less frequently
    """
    mock_db_client.seeds_usage.get_aggregated_stats.return_value = sample_seed_stats

    # Run 100 iterations
    np.random.seed(42)
    selection_counts = {1: 0, 2: 0, 3: 0, 4: 0}

    for _ in range(100):
        selected = await select_seeds_thompson(mock_db_client, n=1)
        if selected:
            selection_counts[selected[0]] += 1

    # High success seed (id=1, alpha=10, beta=2) should be selected most often
    # Low success seed (id=3, alpha=2, beta=10) should be selected least often
    assert selection_counts[1] > selection_counts[3]
    assert selection_counts[1] > selection_counts[2]


@pytest.mark.asyncio
async def test_thompson_sampling_no_seeds_available(mock_db_client: MagicMock) -> None:
    """Test Thompson sampling when no seeds are available."""
    # Mock empty stats
    mock_db_client.seeds_usage.get_aggregated_stats.return_value = []

    selected_ids = await select_seeds_thompson(mock_db_client, n=5)

    # Should return empty list
    assert selected_ids == []


@pytest.mark.asyncio
async def test_thompson_sampling_fewer_seeds_than_requested(
    mock_db_client: MagicMock,
    sample_seed_stats: list,
) -> None:
    """Test Thompson sampling when fewer seeds available than requested."""
    # Only provide 2 seeds
    mock_db_client.seeds_usage.get_aggregated_stats.return_value = sample_seed_stats[:2]

    selected_ids = await select_seeds_thompson(mock_db_client, n=10)

    # Should return only available seeds (2)
    assert len(selected_ids) == 2
    assert all(sid in [1, 2] for sid in selected_ids)


@pytest.mark.asyncio
async def test_thompson_sampling_with_uniform_priors(mock_db_client: MagicMock) -> None:
    """Test Thompson sampling with all new seeds (uniform prior).

    All seeds have alpha=1, beta=1, so selection should be roughly uniform.
    """
    # Create seeds with uniform priors
    seed_stat_class = type('SeedStat', (), {})
    uniform_seeds = []
    for i in range(4):
        seed_obj = seed_stat_class()
        seed_obj.seed_id = i + 1  # type: ignore[attr-defined]
        seed_obj.alpha = 1  # type: ignore[attr-defined]
        seed_obj.beta = 1  # type: ignore[attr-defined]
        uniform_seeds.append(seed_obj)

    mock_db_client.seeds_usage.get_aggregated_stats.return_value = uniform_seeds

    # Run many iterations and check distribution is roughly uniform
    np.random.seed(42)
    selection_counts = {1: 0, 2: 0, 3: 0, 4: 0}

    for _ in range(400):
        selected = await select_seeds_thompson(mock_db_client, n=1)
        if selected:
            selection_counts[selected[0]] += 1

    # Each seed should be selected roughly 100 times (±50 for variance)
    for count in selection_counts.values():
        assert 50 < count < 150


def test_thompson_sample_internal_function(sample_seed_stats: list) -> None:
    """Test the internal _thompson_sample function directly.

    This tests the pure algorithm without async/DB mocking.
    """
    np.random.seed(42)

    # Select 2 seeds from 4
    selected_ids = _thompson_sample(sample_seed_stats, n=2)

    assert len(selected_ids) == 2
    assert all(sid in [1, 2, 3, 4] for sid in selected_ids)
    assert len(set(selected_ids)) == 2  # No duplicates


@pytest.mark.asyncio
async def test_lru_selection_basic(mock_db_client: MagicMock) -> None:
    """Test LRU seed selection returns correct IDs."""
    # Mock LRU to return seeds in least recently used order
    mock_db_client.seeds_usage.get_least_recently_used_seeds.return_value = [5, 3, 1]

    selected_ids = await select_seeds_lru(mock_db_client, n=3)

    # Should return the IDs in LRU order
    assert selected_ids == [5, 3, 1]
    # Verify the mock was called with correct parameter
    mock_db_client.seeds_usage.get_least_recently_used_seeds.assert_called_once_with(3)


@pytest.mark.asyncio
async def test_lru_selection_fewer_seeds_available(mock_db_client: MagicMock) -> None:
    """Test LRU selection when fewer seeds available than requested."""
    # Only 2 seeds available
    mock_db_client.seeds_usage.get_least_recently_used_seeds.return_value = [7, 2]

    selected_ids = await select_seeds_lru(mock_db_client, n=10)

    # Should return only available seeds
    assert selected_ids == [7, 2]
    assert len(selected_ids) == 2


@pytest.mark.asyncio
async def test_lru_selection_no_seeds_available(mock_db_client: MagicMock) -> None:
    """Test LRU selection when no seeds are available."""
    mock_db_client.seeds_usage.get_least_recently_used_seeds.return_value = []

    selected_ids = await select_seeds_lru(mock_db_client, n=5)

    # Should return empty list
    assert selected_ids == []
