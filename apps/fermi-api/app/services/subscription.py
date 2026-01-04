"""Subscription service for handling RevenueCat webhooks."""

import logging
from datetime import datetime

from fermi_db.models.subscription import (
    SubscriptionPlatform,
    SubscriptionTier,
)
from fermi_db.repositories.subscription_repository import SubscriptionRepository
from fermi_db.repositories.user_repository import UserRepository

logger = logging.getLogger(__name__)


class SubscriptionService:
    """Service for subscription-related operations."""

    def __init__(
        self,
        subscription_repository: SubscriptionRepository,
        user_repository: UserRepository,
    ):
        """Initialize the subscription service."""
        self._subscription_repository = subscription_repository
        self._user_repository = user_repository

    def _parse_platform(self, store: str) -> SubscriptionPlatform | None:
        """Parse platform from RevenueCat store string.

        RevenueCat store values: APP_STORE, MAC_APP_STORE, PLAY_STORE, STRIPE,
        PROMOTIONAL, AMAZON, PADDLE, RC_BILLING, ROKU, TEST_STORE
        """
        store_mapping = {
            'APP_STORE': SubscriptionPlatform.APP_STORE,
            'MAC_APP_STORE': SubscriptionPlatform.APP_STORE,
            'PLAY_STORE': SubscriptionPlatform.PLAY_STORE,
            'STRIPE': SubscriptionPlatform.STRIPE,
            'PROMOTIONAL': SubscriptionPlatform.PROMOTIONAL,
            # Unsupported stores (AMAZON, PADDLE, RC_BILLING, ROKU) return None
        }
        return store_mapping.get(store.upper())

    def _parse_tier_from_entitlements(
        self,
        entitlements: dict,
    ) -> SubscriptionTier:
        """Parse subscription tier from RevenueCat entitlements."""
        # Check if user has 'Guesstimate Pro' entitlement active
        if entitlements and 'Guesstimate Pro' in entitlements:
            pro_entitlement = entitlements['Guesstimate Pro']
            if pro_entitlement.get('is_active', False):
                return SubscriptionTier.PRO
        return SubscriptionTier.FREE

    async def _handle_transfer_event(self, event: dict) -> None:
        """Handle a TRANSFER event from RevenueCat.

        TRANSFER events occur when a subscription is transferred between users,
        typically due to a restore purchase on a different account. These events
        use transferred_from/transferred_to arrays instead of app_user_id.

        Args:
            event: The TRANSFER event data.

        """
        transferred_to = event.get('transferred_to', [])
        transferred_from = event.get('transferred_from', [])

        logger.info(
            'Processing TRANSFER event: from=%s, to=%s',
            transferred_from,
            transferred_to,
        )

        # Process each user receiving the subscription
        for app_user_id in transferred_to:
            user = await self._user_repository.get_by_firebase_uid(app_user_id)
            if not user:
                logger.info(
                    'Transferred-to user not in database (may be alias): %s',
                    app_user_id,
                )
                continue

            # Get subscriber info to check current entitlements
            subscriber = event.get('subscriber', {})
            entitlements = subscriber.get('entitlements', {})
            tier = self._parse_tier_from_entitlements(entitlements)

            is_active = tier == SubscriptionTier.PRO

            # Upsert subscription for the receiving user
            assert user.id is not None, 'User ID should be set after retrieval'
            await self._subscription_repository.upsert_subscription(
                user_id=user.id,
                revenuecat_user_id=app_user_id,
                tier=tier,
                product_id=None,  # Not available in TRANSFER event
                platform=None,  # Not available in TRANSFER event
                is_active=is_active,
                expires_at=None,
                original_purchase_date=None,
            )

            logger.info(
                'Transferred subscription to user %d: tier=%s, active=%s',
                user.id,
                tier.value,
                is_active,
            )

        # Optionally, mark subscriptions as inactive for transferred_from users
        for app_user_id in transferred_from:
            user = await self._user_repository.get_by_firebase_uid(app_user_id)
            if not user:
                continue

            # Mark subscription as inactive for the losing user
            assert user.id is not None, 'User ID should be set after retrieval'
            await self._subscription_repository.upsert_subscription(
                user_id=user.id,
                revenuecat_user_id=app_user_id,
                tier=SubscriptionTier.FREE,
                product_id=None,
                platform=None,
                is_active=False,
                expires_at=None,
                original_purchase_date=None,
            )

            logger.info(
                'Removed subscription from user %d after transfer',
                user.id,
            )

    async def handle_webhook_event(
        self,
        payload: dict,
    ) -> None:
        """Handle a RevenueCat webhook event.

        Args:
            payload: The webhook payload from RevenueCat.
                     Contains an 'event' object with the actual event data.

        """
        # RevenueCat nests event data inside an 'event' key
        event = payload.get('event', payload)

        event_type = event.get('type')

        # TRANSFER events have a different structure - they use
        # transferred_from/transferred_to arrays instead of app_user_id.
        if event_type == 'TRANSFER':
            await self._handle_transfer_event(event)
            return

        # For other events, try app_user_id first, fall back to original_app_user_id
        app_user_id = event.get('app_user_id') or event.get('original_app_user_id')

        logger.info(
            'Processing webhook event: type=%s, app_user_id=%s',
            event_type,
            app_user_id,
        )

        if not app_user_id:
            logger.warning(
                'Webhook event missing app_user_id: type=%s, keys=%s',
                event_type,
                list(event.keys()),
            )
            return

        # Find user by RevenueCat app_user_id (which should match firebase_uid)
        user = await self._user_repository.get_by_firebase_uid(app_user_id)
        if not user:
            logger.warning(
                'User not found for RevenueCat app_user_id: %s',
                app_user_id,
            )
            return

        # Parse subscription details from customer_info
        customer_info = event.get('subscriber', {})
        entitlements = customer_info.get('entitlements', {})
        tier = self._parse_tier_from_entitlements(entitlements)

        # Get product info from active entitlements
        product_id = None
        platform = None
        expires_at = None
        original_purchase_date = None
        is_active = tier == SubscriptionTier.PRO

        if is_active and entitlements.get('Guesstimate Pro'):
            pro_entitlement = entitlements['Guesstimate Pro']
            product_id = pro_entitlement.get('product_identifier')
            expires_at_str = pro_entitlement.get('expires_date')
            if expires_at_str:
                try:
                    # Parse ISO format datetime
                    expires_at = datetime.fromisoformat(
                        expires_at_str.replace('Z', '+00:00'),
                    )
                except (ValueError, AttributeError):
                    logger.warning(
                        'Failed to parse expires_at: %s',
                        expires_at_str,
                    )

            # Get platform from store
            store = pro_entitlement.get('store')
            if store:
                platform = self._parse_platform(store)

            # Get original purchase date
            original_purchase_date_str = pro_entitlement.get('original_purchase_date')
            if original_purchase_date_str:
                try:
                    original_purchase_date = datetime.fromisoformat(
                        original_purchase_date_str.replace('Z', '+00:00'),
                    )
                except (ValueError, AttributeError):
                    logger.warning(
                        'Failed to parse original_purchase_date: %s',
                        original_purchase_date_str,
                    )

        # Upsert subscription record
        assert user.id is not None, 'User ID should be set after retrieval'
        await self._subscription_repository.upsert_subscription(
            user_id=user.id,
            revenuecat_user_id=app_user_id,
            tier=tier,
            product_id=product_id,
            platform=platform,
            is_active=is_active,
            expires_at=expires_at,
            original_purchase_date=original_purchase_date,
        )

        logger.info(
            'Updated subscription for user %d: tier=%s, active=%s',
            user.id,
            tier.value,
            is_active,
        )
