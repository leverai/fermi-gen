"""Game service utilities.

This module contains shared constants, type aliases, and simple helper
functions used across the game service. It should not contain complex logic.
"""

from typing import TYPE_CHECKING, Union

from fastapi import Request
from fermi_db.schemas import QuestionDifficulty

from app.schemas.endpoints import GameConfigResponse, RequestCategory

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import (
        AsyncTransaction,
        AsyncWriteBatch,
    )


# Writable types for firestore transactions
Writeable = Union['AsyncWriteBatch', 'AsyncTransaction']


def get_request_categories() -> list[GameConfigResponse.CategoryInfo]:
    """Return ordered categories exposed to clients with theme and assets.

    - Excludes OTHER
    - Provides slug and picture path for frontend
    """
    categories: list[tuple[RequestCategory, str]] = [
        (RequestCategory.PLANET_EARTH, 'Planet Earth'),
        (RequestCategory.POP_CULTURE, 'Pop Culture'),
        (RequestCategory.COSMIC_PERSPECTIVE, 'Cosmic Gauge'),
        (RequestCategory.SHOWER_THOUGHTS, 'Shower Thoughts'),
        (RequestCategory.HUMANITY_BY_NUMBERS, 'Mass Motion'),
    ]

    result: list[GameConfigResponse.CategoryInfo] = []
    for idx, (name, slug) in enumerate(categories):
        result.append(
            GameConfigResponse.CategoryInfo(
                index=idx,
                name=name,
                slug=slug,
            ),
        )
    return result


def get_request_difficulties(
    request: Request | None = None,
) -> list[GameConfigResponse.DifficultyInfo]:
    """Return ordered difficulties exposed to clients."""
    base = str(request.base_url).rstrip('/') if request else None
    snail = (
        f'{base}/static/difficulties/snail.svg'
        if base
        else '/static/difficulties/snail.svg'
    )
    rocket = (
        f'{base}/static/difficulties/rocket.svg'
        if base
        else '/static/difficulties/rocket.svg'
    )
    thunder = (
        f'{base}/static/difficulties/thunder.svg'
        if base
        else '/static/difficulties/thunder.svg'
    )
    return [
        GameConfigResponse.DifficultyInfo(
            name=QuestionDifficulty.EASY,
            slug='Easy',
            picture=snail,
        ),
        GameConfigResponse.DifficultyInfo(
            name=QuestionDifficulty.MEDIUM,
            slug='Pro',
            picture=rocket,
        ),
        GameConfigResponse.DifficultyInfo(
            name=QuestionDifficulty.HARD,
            slug='Expert',
            picture=thunder,
        ),
    ]
