"""Game service utilities.

This module contains shared constants, type aliases, and simple helper
functions used across the game service. It should not contain complex logic.
"""

from typing import TYPE_CHECKING, Union

from fastapi import HTTPException, Request, status
from fermi_db.schemas import QuestionDifficulty

from app.schemas.endpoints import GameConfigResponse, RequestCategory
from app.schemas.game import GameState

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import (
        AsyncTransaction,
        AsyncWriteBatch,
    )


# Grace tolerance (seconds) added when enforcing question deadlines. This allows
# for small client-server clock drift and network latency. Enforcement happens
# exclusively in the ``SubmitAnswerUseCase``.
DIFFICULTY_TIMEOUT_SECONDS = {
    QuestionDifficulty.EASY: 30,
    QuestionDifficulty.MEDIUM: 35,
    QuestionDifficulty.HARD: 40,
}


# Writable types for firestore transactions
Writeable = Union['AsyncWriteBatch', 'AsyncTransaction']


def assert_state_in(got: GameState, *expected: GameState) -> None:
    """Assert game state."""
    if got not in expected:
        expected_names = [state.name for state in expected]
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f'State conflict: Expected {expected_names}, got {got.name}',
        )


def assert_state_le(got: GameState, le: GameState) -> None:
    """Assert game state is less than or equal to the given state."""
    if got > le:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f'State conflict: Expected {got.name} <= {le.name}',
        )


def get_request_categories(
    request: Request | None = None,
) -> list[GameConfigResponse.CategoryInfo]:
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
    base = None
    if request is not None:
        base = str(request.base_url).rstrip('/')
    for idx, (name, slug) in enumerate(categories):
        picture = f'/static/categories/{name}.svg'
        if base:
            picture = f'{base}{picture}'
        result.append(
            GameConfigResponse.CategoryInfo(
                index=idx,
                name=name,
                slug=slug,
                picture=picture,
            ),
        )
    return result


def get_request_difficulties(
    request: Request,
) -> list[GameConfigResponse.DifficultyInfo]:
    """Return ordered difficulties exposed to clients."""
    base = str(request.base_url).rstrip('/')
    return [
        GameConfigResponse.DifficultyInfo(
            name=QuestionDifficulty.EASY,
            slug='Easy',
            picture=f'{base}/static/difficulties/snail.svg',
        ),
        GameConfigResponse.DifficultyInfo(
            name=QuestionDifficulty.MEDIUM,
            slug='Pro',
            picture=f'{base}/static/difficulties/rocket.svg',
        ),
        GameConfigResponse.DifficultyInfo(
            name=QuestionDifficulty.HARD,
            slug='Expert',
            picture=f'{base}/static/difficulties/thunder.svg',
        ),
    ]
