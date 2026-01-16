"""Subscription model."""

from datetime import datetime
from enum import StrEnum

import sqlalchemy as sa
from fermi_core import utcnow_naive
from sqlmodel import Field, SQLModel


class SubscriptionTier(StrEnum):
    """Subscription tier levels."""

    FREE = 'FREE'
    PRO = 'PRO'


class SubscriptionPlatform(StrEnum):
    """Platform where subscription was purchased."""

    APP_STORE = 'APP_STORE'
    PLAY_STORE = 'PLAY_STORE'
    STRIPE = 'STRIPE'
    PROMOTIONAL = 'PROMOTIONAL'


class Subscription(SQLModel, table=True):
    """Subscription table tracking user subscription status."""

    __tablename__ = 'subscriptions'  # type: ignore[assignment]

    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key='user.id', unique=True, index=True)
    revenuecat_user_id: str = Field(index=True)
    tier: SubscriptionTier = Field(default=SubscriptionTier.FREE)
    product_id: str | None = None  # e.g., 'fermi_pro_lifetime'
    platform: SubscriptionPlatform | None = None
    is_active: bool = Field(default=False)
    expires_at: datetime | None = Field(
        default=None,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )  # NULL for lifetime
    original_purchase_date: datetime | None = Field(
        default=None,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    created_at: datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    updated_at: datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
