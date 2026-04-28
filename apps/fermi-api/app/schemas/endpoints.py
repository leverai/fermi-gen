"""Pydantic models for endpoints-related requests and responses."""

import re
from enum import StrEnum
from typing import TypeAlias

from fermi_db.schemas import (
    Locale,
    QuestionCategory,
    QuestionDifficulty,
)
from pydantic import BaseModel, Field, field_validator

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


class IdModel(BaseModel):
    """ID model."""

    resource_id: str


class VoteVerdictResponse(BaseModel):
    """Response with resulting vote verdict value for a question/user."""

    resource_id: str
    verdict: int


class PlayerStats(BaseModel):
    """Player stats."""

    class RankInfo(BaseModel):
        """Player rank info."""

        id: int
        """Rank tier ID (1-5)."""

        name: str
        """Rank name (e.g., 'The Fermi')."""

        picture: str
        """URL to the rank image."""

        accuracy_vibe: str
        """Accuracy vibe descriptor (e.g., 'Uncanny')."""

        tagline: str
        """Rank tagline (e.g., 'Close enough for physics.')."""

    total_party_games: int
    """Total party mode games played."""

    total_daily_guesses: int
    """Total daily questions answered."""

    total_survival_runs: int
    """Total survival runs."""

    average_percentile: int
    """Average percentile (0-100)."""

    rank: RankInfo
    """Player rank based on average percentile."""

    xp: int
    """Player's total experience points."""

    level: int
    """Player level (computed from xp)."""

    points: int
    """Player's consumable points balance."""


class GetPlayerStatsResponse(BaseModel):
    """Response model for getting a player's stats."""

    player_id: str
    stats: PlayerStats


class SpendPointsRequest(BaseModel):
    """Request model for spending points."""

    amount: int = Field(gt=0, description='Amount of points to spend')


class SpendPointsResponse(BaseModel):
    """Response model for spending points."""

    remaining_points: int


class EarnAdPointsResponse(BaseModel):
    """Response model for earning points by watching an ad."""

    new_balance: int


class UserLimits(BaseModel):
    """User-specific limits based on subscription tier."""

    party_hostings_remaining: int
    """Number of party hostings remaining this week. -1 for unlimited (Pro users)."""

    survival_runs_remaining: int
    """Number of survival runs remaining today. -1 for unlimited (Pro users)."""

    precision_rush_runs_remaining: int
    """Number of precision rush runs remaining today. -1 for unlimited (Pro users)."""


class UserLimitsResponse(BaseModel):
    """Response model for getting user-specific limits."""

    limits: UserLimits


class GameConfigResponse(BaseModel):
    """Response model for getting the game config."""

    class CategoryInfo(BaseModel):
        """Category info with theme and assets."""

        index: int
        name: RequestCategory
        slug: str

    class DifficultyInfo(BaseModel):
        """Difficulty info."""

        name: QuestionDifficulty
        slug: str
        picture: str

    class RankDefinition(BaseModel):
        """Rank tier definition for display in the ranks screen."""

        id: int
        """Rank tier ID (1-5)."""

        name: str
        """Rank name (e.g., 'Fermi')."""

        min_percentile: int
        """Minimum percentile to achieve this rank."""

        accuracy_vibe: str
        """Accuracy vibe descriptor (e.g., 'Uncanny')."""

        tagline: str
        """Rank tagline (e.g., 'Close enough for physics.')."""

        picture: str
        """URL to the rank image."""

    categories: list['GameConfigResponse.CategoryInfo']
    difficulties: list['GameConfigResponse.DifficultyInfo']
    ranks: list['GameConfigResponse.RankDefinition']


class SetLocaleRequest(BaseModel):
    """Request model for setting a user's locale."""

    locale: Locale


class UpdateUserProfileRequest(BaseModel):
    """Request model for updating a user's profile."""

    display_name: str | None = Field(default=None, max_length=50)
    avatar_url: str | None = Field(default=None, max_length=500)

    @field_validator('display_name')
    @classmethod
    def validate_display_name(cls, v: str | None) -> str | None:
        """Validate display name contains only safe characters."""
        if v is None:
            return v
        # Allow alphanumeric, spaces, and common punctuation (-, _, ., ')
        if not re.match(r'^[\w\s\-_.\']+$', v, re.UNICODE):
            raise ValueError('Display name contains invalid characters')
        return v.strip()

    @field_validator('avatar_url')
    @classmethod
    def validate_avatar_url(cls, v: str | None) -> str | None:
        """Validate avatar URL is safe (internal asset or HTTPS URL)."""
        if v is None:
            return v
        # Allow relative paths starting with /static/avatars/ (internal)
        # or absolute URLs with https scheme (OAuth providers like Google)
        if v.startswith('/static/avatars/'):
            return v
        if v.startswith('https://') or v.startswith('http://localhost'):
            return v
        raise ValueError('Avatar URL must be an internal asset or valid HTTPS URL')


class AvatarInfo(BaseModel):
    """Avatar info with unlock level and group."""

    url: str
    """Full URL to the avatar asset."""

    unlock_level: int
    """Level required to unlock this avatar."""

    unlocked: bool
    """Whether this avatar is unlocked for the requesting user."""

    group: str
    """Avatar group (e.g., 'animals', 'letters', 'folks')."""


class GetAvatarsResponse(BaseModel):
    """Response model for getting avatars."""

    avatars: list[AvatarInfo]
