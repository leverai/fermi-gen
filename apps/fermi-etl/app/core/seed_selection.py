"""Seed selection strategies for question generation."""

import logging

import numpy as np
from fermi_db import DatabaseClient

logger = logging.getLogger(__name__)


async def select_seeds_thompson(
    db_client: DatabaseClient,
    n: int,
) -> list[int]:
    """Select seeds using Thompson Sampling (explore/exploit).

    Thompson Sampling samples from Beta(alpha, beta) distribution for each seed
    where:
    - alpha = total_yielded + 1 (successes)
    - beta = (total_requested - total_yielded) + 1 (failures)

    Seeds without usage history get a uniform prior Beta(1, 1), representing
    complete uncertainty. This ensures new seeds can be explored naturally
    through the Thompson Sampling mechanism.

    Args:
        db_client: Database client instance
        n: Number of seeds to select

    Returns:
        List of selected seed IDs

    """
    # Get aggregated statistics for all seeds (includes unused seeds with prior)
    stats = await db_client.seeds_usage.get_aggregated_stats()

    if not stats:
        logger.warning('No seeds available in database')
        return []

    if len(stats) < n:
        logger.warning(
            f'Only {len(stats)} seeds available, '
            f'but {n} requested. Selecting all available seeds.',
        )
        n = len(stats)

    # Sample theta from Beta(alpha, beta) for each seed
    selected_seed_ids = _thompson_sample(stats, n)

    logger.info(
        f'Selected {len(selected_seed_ids)} seeds using Thompson Sampling '
        f'(from {len(stats)} total seeds)',
    )
    return selected_seed_ids


def _thompson_sample(stats: list, n: int) -> list[int]:
    """Sample n seeds using Thompson Sampling algorithm.

    Args:
        stats: List of SeedStats with alpha/beta parameters
        n: Number of seeds to sample

    Returns:
        List of selected seed IDs

    """
    # Sample theta from Beta(alpha, beta) for each seed
    samples = []
    for stat in stats:
        theta = np.random.beta(stat.alpha, stat.beta)
        samples.append((theta, stat.seed_id))

    # Sort by sampled theta (descending) and select top-n
    samples.sort(reverse=True, key=lambda x: x[0])
    selected_seed_ids = [seed_id for _, seed_id in samples[:n]]

    return selected_seed_ids


async def select_seeds_lru(
    db_client: DatabaseClient,
    n: int,
) -> list[int]:
    """Select seeds using Least Recently Used strategy (pure exploration).

    Args:
        db_client: Database client instance
        n: Number of seeds to select

    Returns:
        List of selected seed IDs

    """
    seed_ids = await db_client.seeds_usage.get_least_recently_used_seeds(n)
    logger.info(f'Selected {len(seed_ids)} seeds using LRU strategy')
    return seed_ids
