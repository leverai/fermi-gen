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
    QuestionDifficulty.EASY: 15,
    QuestionDifficulty.MEDIUM: 25,
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


def _theme(
    background: str,
    foreground: str,
    foreground_negative: str,
    foreground_p30: str,
    foreground_negative_p30: str,
) -> GameConfigResponse.ThemeColors:
    return GameConfigResponse.ThemeColors(
        background=background,
        foreground=foreground,
        foreground_negative=foreground_negative,
        foreground_p30=foreground_p30,
        foreground_negative_p30=foreground_negative_p30,
    )


def get_request_categories(
    request: Request | None = None,
) -> list[GameConfigResponse.CategoryInfo]:
    """Return ordered categories exposed to clients with theme and assets.

    - Excludes OTHER
    - Provides slug and picture path for frontend
    """
    bg = '0xFF141414'
    categories: list[tuple[RequestCategory, str, GameConfigResponse.ThemeColors]] = [
        (
            RequestCategory.PLANET_EARTH,
            'Planet Earth',
            _theme(
                background=bg,
                foreground='0xFF94B4A9',
                foreground_negative='0xFFF4C851',
                foreground_p30='0x4D94B4A9',
                foreground_negative_p30='0x4DF4C851',
            ),
        ),
        (
            RequestCategory.POP_CULTURE,
            'Pop Culture',
            _theme(
                background=bg,
                foreground='0xFFEFBD28',
                foreground_negative='0xFFDE5074',
                foreground_p30='0x4DEFBD28',
                foreground_negative_p30='0x4DDE5074',
            ),
        ),
        (
            RequestCategory.COSMIC_PERSPECTIVE,
            'Cosmic Gauge',
            _theme(
                background=bg,
                foreground='0xFFD37168',
                foreground_negative='0xFFD2C38F',
                foreground_p30='0x4DD37168',
                foreground_negative_p30='0x4DF2C38F',
            ),
        ),
        (
            RequestCategory.SHOWER_THOUGHTS,
            'Shower Thoughts',
            _theme(
                background=bg,
                foreground='0xFFC48876',
                foreground_negative='0xFFB3CEBD',
                foreground_p30='0x4DC48876',
                foreground_negative_p30='0x4DB3CEBD',
            ),
        ),
        (
            RequestCategory.HUMANITY_BY_NUMBERS,
            'Mass Motion',
            _theme(
                background=bg,
                foreground='0xFFE6922B',
                foreground_negative='0xFFfefefe',
                foreground_p30='0x4DE6922B',
                foreground_negative_p30='0x4Dfefefe',
            ),
        ),
    ]

    result: list[GameConfigResponse.CategoryInfo] = []
    base = None
    if request is not None:
        base = str(request.base_url).rstrip('/')
    for idx, (name, slug, theme) in enumerate(categories):
        picture = f'/static/categories/{name}.svg'
        if base:
            picture = f'{base}{picture}'
        result.append(
            GameConfigResponse.CategoryInfo(
                index=idx,
                name=name,
                slug=slug,
                theme=theme,
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
