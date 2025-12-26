"""Rank calculation utilities.

This module defines the player ranking tiers and provides functions
to compute a player's rank based on their average percentile.
"""

from fastapi import Request

from app.schemas.endpoints import PlayerStats

# Rank definitions: (tier_id, name, min_percentile, image_filename)
# Ordered from highest to lowest tier for efficient lookup
RANKS = [
    (5, 'Fermi Master', 98),  # Top 2%
    (4, 'Strategist', 90),  # Top 10%
    (3, 'Analyst', 75),  # Top 25%
    (2, 'Guesstimator', 40),  # Top 60%
    (1, 'Observer', 0),  # Bottom 40%
]


def get_rank_for_percentile(
    avg_percentile: int,
    request: Request | None = None,
) -> PlayerStats.RankInfo:
    """Compute the rank for a given average percentile.

    Args:
        avg_percentile: The player's average percentile (0-100).
        request: Optional FastAPI request to build absolute image URLs.

    Returns:
        RankInfo with tier id, name, and picture URL.

    """
    # Determine base URL for images
    base = str(request.base_url).rstrip('/') if request else ''

    # Find the appropriate rank (ordered highest to lowest)
    for tier_id, name, min_percentile in RANKS:
        if avg_percentile >= min_percentile:
            picture = f'{base}/static/ranks/{tier_id}.svg'
            return PlayerStats.RankInfo(
                id=tier_id,
                name=name,
                picture=picture,
            )

    # Fallback to lowest rank (should never reach here)
    return PlayerStats.RankInfo(
        id=1,
        name='Observer',
        picture=f'{base}/static/ranks/1.svg',
    )
