"""Pydantic models for endpoints-related requests and responses."""

from enum import StrEnum
from typing import TypeAlias

from fermi_db.schemas import (
    AnswerBare,
    Locale,
    QuestionCategory,
    QuestionDifficulty,
)
from pydantic import BaseModel

RequestDifficulty: TypeAlias = QuestionDifficulty | None
"""Requested difficulty."""


class QuestionSettings(BaseModel):
    """A question's category and difficulty."""

    category: QuestionCategory
    difficulty: QuestionDifficulty


class RequestCategory(StrEnum):
    """Categories exposed to clients for requests/config."""

    PLANET_EARTH = 'PLANET_EARTH'
    HUMANITY_BY_NUMBERS = 'HUMANITY_BY_NUMBERS'
    POP_CULTURE = 'POP_CULTURE'
    SHOWER_THOUGHTS = 'SHOWER_THOUGHTS'
    COSMIC_PERSPECTIVE = 'COSMIC_PERSPECTIVE'


class QuestionRoundSettings(BaseModel):
    """Question round criteria."""

    n_questions: int = 6
    category: RequestCategory | None = None
    difficulty: RequestDifficulty


class GameCreateRequest(BaseModel):
    """Request model for creating a new game."""

    question_round_settings: QuestionRoundSettings
    is_private: bool


class IdModel(BaseModel):
    """ID model."""

    resource_id: str


class AddBotsRequest(IdModel):
    """Request model for adding bots to a game by ID.

    The host can add bots to any game in lobby state by specifying their IDs.
    All IDs must be valid and unique. Max players limit (8) is enforced.
    """

    bot_ids: list[str]


class VoteVerdictResponse(BaseModel):
    """Response with resulting vote verdict value for a question/user."""

    resource_id: str
    verdict: int


class GameJoinRandomRequest(BaseModel):
    """Request model for joining a random game."""

    resource_id: str | None = None
    question_round_settings: QuestionRoundSettings


class GameAnswerRequest(IdModel):
    """Request model for answering a question."""

    answer: AnswerBare


class GameRemovePlayerRequest(IdModel):
    """Request model for removing a player from a game."""

    player_id: str


class GetPlayerStatsRequest(BaseModel):
    """Request model for getting a player's stats."""

    player_id: str


class PlayerStats(BaseModel):
    """Player stats."""

    total_party_games: int
    """Total party mode games played."""

    total_daily_guesses: int
    """Total daily questions answered."""

    average_percentile: int
    """Average percentile (0-100)."""

    level: int
    """Player level (not yet implemented, always 1)."""


class GetPlayerStatsResponse(BaseModel):
    """Response model for getting a player's stats."""

    player_id: str
    stats: PlayerStats


class GameConfigResponse(BaseModel):
    """Response model for getting the game config."""

    class CategoryInfo(BaseModel):
        """Category info with theme and assets."""

        index: int
        name: RequestCategory
        slug: str
        picture: str

    class DifficultyInfo(BaseModel):
        """Difficulty info."""

        name: QuestionDifficulty
        slug: str
        picture: str

    categories: list['GameConfigResponse.CategoryInfo']
    difficulties: list['GameConfigResponse.DifficultyInfo']


class SetLocaleRequest(BaseModel):
    """Request model for setting a user's locale."""

    locale: Locale


class UpdateUserProfileRequest(BaseModel):
    """Request model for updating a user's profile."""

    display_name: str | None = None
    avatar_url: str | None = None


class GetAvatarsResponse(BaseModel):
    """Response model for getting avatars."""

    avatars: list[str]
