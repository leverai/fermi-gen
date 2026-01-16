"""Authenticated user model with subscription tier."""

from fermi_db.models.subscription import SubscriptionTier
from fermi_db.models.user import User
from pydantic import BaseModel, ConfigDict

from app.core.config import settings


class AuthenticatedUser(BaseModel):
    """User model enriched with subscription tier.

    Use this instead of plain User when you need to check subscription status
    for feature gating.
    """

    model_config = ConfigDict(arbitrary_types_allowed=True)

    user: User
    tier: SubscriptionTier = SubscriptionTier.FREE

    @property
    def is_pro(self) -> bool:
        """Check if user has Pro subscription or is in bypass list."""
        if self.user.email and self.user.email in settings.pro_bypass_emails:
            return True
        return self.tier == SubscriptionTier.PRO

    # Delegate common user attributes for convenience
    @property
    def id(self) -> int:
        """User database ID."""
        assert self.user.id is not None
        return self.user.id

    @property
    def firebase_uid(self) -> str:
        """User Firebase UID."""
        return self.user.firebase_uid

    @property
    def locale(self) -> str:
        """User locale."""
        return self.user.locale
