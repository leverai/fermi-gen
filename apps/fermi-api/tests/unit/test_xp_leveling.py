"""Unit tests for XP and leveling system.

Tests the XP increment and level calculation formulas:
- xp_increment = score // 100
- level = (xp // 100) + 1
"""

from unittest.mock import AsyncMock, MagicMock

import pytest


class TestXpLevelFormulaCalculations:
    """Test the XP and level calculation formulas."""

    def test_xp_increment_from_score(self) -> None:
        """XP increment should be score // 100."""
        # Formula: xp_increment = score // 100
        assert 0 // 100 == 0
        assert int(99.9 // 100) == 0  # Float division needs int()
        assert 100 // 100 == 1
        assert 199 // 100 == 1
        assert 200 // 100 == 2
        assert 599 // 100 == 5
        assert 6000 // 100 == 60  # Max score

    def test_level_from_xp(self) -> None:
        """Level should be (xp // 100) + 1."""
        # Formula: level = (xp // 100) + 1
        assert (0 // 100) + 1 == 1  # Level 1 at 0 XP
        assert (99 // 100) + 1 == 1  # Still level 1 at 99 XP
        assert (100 // 100) + 1 == 2  # Level 2 at 100 XP
        assert (199 // 100) + 1 == 2  # Still level 2 at 199 XP
        assert (200 // 100) + 1 == 3  # Level 3 at 200 XP
        assert (9999 // 100) + 1 == 100  # Level 100 at 9999 XP
        assert (10000 // 100) + 1 == 101  # Level 101 at 10000 XP

    def test_level_boundaries(self) -> None:
        """Test level boundaries are consistent."""
        for xp in [0, 1, 50, 99]:
            assert (xp // 100) + 1 == 1

        for xp in [100, 150, 199]:
            assert (xp // 100) + 1 == 2

        for xp in [200, 250, 299]:
            assert (xp // 100) + 1 == 3


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
