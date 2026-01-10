"""Rank calculation utilities.

This module defines the player ranking tiers and provides functions
to compute a player's rank based on their average percentile.
"""

from fastapi import Request

from app.schemas.endpoints import PlayerStats

# Rank definitions: (tier_id, name, min_percentile, accuracy_vibe, tagline)
# Ordered from highest to lowest tier for efficient lookup
RANKS = [
    (5, 'Fermi', 98, 'Uncanny', 'Close enough for physics.'),
    (4, 'Eratosthenes', 90, 'Precise', "Give me a stick, and I'll measure the world."),
    (3, 'Archimedes', 75, 'Theoretical', 'But my math is right!'),
    (2, 'Kelvin', 40, 'Flawed Genius', 'Technically correct, practically wrong.'),
    (1, 'Columbus', 0, 'Lost', 'India is right around the corner, I swear.'),
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
        RankInfo with tier id, name, picture URL, accuracy vibe, and tagline.

    """
    # Determine base URL for images
    base = str(request.base_url).rstrip('/') if request else ''

    # Find the appropriate rank (ordered highest to lowest)
    for tier_id, name, min_percentile, accuracy_vibe, tagline in RANKS:
        if avg_percentile >= min_percentile:
            picture = f'{base}/static/ranks/{tier_id}.svg'
            return PlayerStats.RankInfo(
                id=tier_id,
                name=name,
                picture=picture,
                accuracy_vibe=accuracy_vibe,
                tagline=tagline,
            )

    # Fallback to lowest rank (should never reach here)
    return PlayerStats.RankInfo(
        id=1,
        name='The Columbus',
        picture=f'{base}/static/ranks/1.svg',
        accuracy_vibe='Lost',
        tagline='India is right around the corner, I swear.',
    )
