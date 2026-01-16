"""Unit tests for AuthenticatedUser."""

from unittest.mock import patch

from fermi_db.models.subscription import SubscriptionTier
from fermi_db.models.user import User

from app.api.v1.authenticated_user import AuthenticatedUser


def _make_user(email: str | None = None) -> User:
    """Create a test user."""
    return User(
        id=1,
        firebase_uid='test-uid',
        email=email,
        display_name='Test User',
    )


class TestIsPro:
    """Tests for AuthenticatedUser.is_pro property."""

    def test_pro_tier_is_pro(self) -> None:
        """User with PRO tier should be pro."""
        auth_user = AuthenticatedUser(
            user=_make_user(email='regular@example.com'),
            tier=SubscriptionTier.PRO,
        )
        assert auth_user.is_pro is True

    def test_free_tier_not_pro(self) -> None:
        """User with FREE tier should not be pro."""
        auth_user = AuthenticatedUser(
            user=_make_user(email='regular@example.com'),
            tier=SubscriptionTier.FREE,
        )
        assert auth_user.is_pro is False

    def test_bypass_email_is_pro(self) -> None:
        """User with bypass email should be pro regardless of tier."""
        with patch(
            'app.api.v1.authenticated_user.settings.pro_bypass_emails',
            ['bypass@test.com'],
        ):
            auth_user = AuthenticatedUser(
                user=_make_user(email='bypass@test.com'),
                tier=SubscriptionTier.FREE,
            )
            assert auth_user.is_pro is True

    def test_bypass_email_case_sensitive(self) -> None:
        """Bypass email check should be case-sensitive."""
        with patch(
            'app.api.v1.authenticated_user.settings.pro_bypass_emails',
            ['bypass@test.com'],
        ):
            auth_user = AuthenticatedUser(
                user=_make_user(email='BYPASS@test.com'),
                tier=SubscriptionTier.FREE,
            )
            # Different case should not match
            assert auth_user.is_pro is False

    def test_none_email_not_bypassed(self) -> None:
        """User with None email should not trigger bypass."""
        with patch(
            'app.api.v1.authenticated_user.settings.pro_bypass_emails',
            ['bypass@test.com'],
        ):
            auth_user = AuthenticatedUser(
                user=_make_user(email=None),
                tier=SubscriptionTier.FREE,
            )
            assert auth_user.is_pro is False
