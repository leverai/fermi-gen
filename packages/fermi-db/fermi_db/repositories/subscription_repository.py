"""Repository for subscription-related database operations."""

from datetime import datetime

from fermi_core import utcnow_naive
from sqlmodel import select

from fermi_db.models.subscription import (
    Subscription,
    SubscriptionPlatform,
    SubscriptionTier,
)

from . import BaseRepository


class SubscriptionRepository(BaseRepository):
    """Handles database operations related to subscriptions."""

    async def get_by_user_id(self, user_id: int) -> Subscription | None:
        """Fetch a subscription by user ID."""
        result = await self.session.exec(
            select(Subscription).where(Subscription.user_id == user_id),
        )
        return result.one_or_none()

    async def get_by_revenuecat_user_id(
        self,
        revenuecat_user_id: str,
    ) -> Subscription | None:
        """Fetch a subscription by RevenueCat app user ID."""
        result = await self.session.exec(
            select(Subscription).where(
                Subscription.revenuecat_user_id == revenuecat_user_id,
            ),
        )
        return result.one_or_none()

    async def upsert_subscription(
        self,
        user_id: int,
        revenuecat_user_id: str,
        tier: SubscriptionTier,
        product_id: str | None = None,
        platform: SubscriptionPlatform | None = None,
        is_active: bool = False,  # noqa: FBT001, FBT002
        expires_at: datetime | None = None,
        original_purchase_date: datetime | None = None,
    ) -> Subscription:
        """Create or update a subscription record."""
        subscription = await self.get_by_user_id(user_id)

        if subscription is None:
            subscription = Subscription(
                user_id=user_id,
                revenuecat_user_id=revenuecat_user_id,
                tier=tier,
                product_id=product_id,
                platform=platform,
                is_active=is_active,
                expires_at=expires_at,
                original_purchase_date=original_purchase_date,
            )
            self.session.add(subscription)
        else:
            subscription.revenuecat_user_id = revenuecat_user_id
            subscription.tier = tier
            subscription.product_id = product_id
            subscription.platform = platform
            subscription.is_active = is_active
            subscription.expires_at = expires_at
            if original_purchase_date is not None:
                subscription.original_purchase_date = original_purchase_date
            subscription.updated_at = utcnow_naive()

        await self.session.commit()
        await self.session.refresh(subscription)
        return subscription
