"""Unit tests for XP and leveling system.

Tests the XP increment and level calculation formulas:
- xp_increment = score // 100
- level = (xp // 100) + 1
"""

from unittest.mock import AsyncMock, MagicMock

import pytest


@pytest.fixture
def mock_user_repository() -> MagicMock:
    """Create a mock user repository."""
    mock = MagicMock()
    mock.get_xp = AsyncMock(return_value=0)
    mock.increment_xp = AsyncMock()
    mock.get_by_firebase_uid = AsyncMock(return_value=MagicMock())
    mock.session.commit = AsyncMock()
    return mock


class TestUserServiceXpMethods:
    """Test UserService XP methods."""

    @pytest.mark.asyncio
    async def test_increment_xp_by_score_zero(
        self,
        mock_user_repository: MagicMock,
    ) -> None:
        """No XP should be added for scores under 100."""
        from app.services.user import UserService

        service = UserService(user_repository=mock_user_repository)

        result = await service.increment_xp_by_score('uid123', score=99.9)

        assert result == 0
        mock_user_repository.increment_xp.assert_not_called()

    @pytest.mark.asyncio
    async def test_increment_xp_by_score_positive(
        self,
        mock_user_repository: MagicMock,
    ) -> None:
        """XP should be incremented for scores >= 100."""
        from app.services.user import UserService

        service = UserService(user_repository=mock_user_repository)

        result = await service.increment_xp_by_score('uid123', score=250.0)

        assert result == 2
        mock_user_repository.increment_xp.assert_called_once_with('uid123', 2)

    @pytest.mark.asyncio
    async def test_increment_xp_by_score_max_score(
        self,
        mock_user_repository: MagicMock,
    ) -> None:
        """Max score of 6000 should give 60 XP."""
        from app.services.user import UserService

        service = UserService(user_repository=mock_user_repository)

        result = await service.increment_xp_by_score('uid123', score=6000.0)

        assert result == 60
        mock_user_repository.increment_xp.assert_called_once_with('uid123', 60)

    @pytest.mark.asyncio
    async def test_get_xp_level_new_user(
        self,
        mock_user_repository: MagicMock,
    ) -> None:
        """New user with 0 XP should be level 1."""
        from app.services.user import UserService

        mock_user_repository.get_xp = AsyncMock(return_value=0)
        service = UserService(user_repository=mock_user_repository)

        result = await service.get_xp_level('uid123')

        assert result == {'xp': 0, 'level': 1}

    @pytest.mark.asyncio
    async def test_get_xp_level_high_xp(
        self,
        mock_user_repository: MagicMock,
    ) -> None:
        """User with 500 XP should be level 6."""
        from app.services.user import UserService

        mock_user_repository.get_xp = AsyncMock(return_value=500)
        service = UserService(user_repository=mock_user_repository)

        result = await service.get_xp_level('uid123')

        assert result == {'xp': 500, 'level': 6}
