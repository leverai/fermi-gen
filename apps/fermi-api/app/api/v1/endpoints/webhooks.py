"""Webhook endpoints for external services."""

from typing import Annotated, Literal

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Request,
    status,
)
from fermi_db.repositories.subscription_repository import SubscriptionRepository
from fermi_db.repositories.user_repository import UserRepository

from app.api.v1.dependencies import (
    get_subscription_repository,
    get_user_repository,
)
from app.core.config import settings
from app.services.subscription import SubscriptionService

router = APIRouter()


async def verify_webhook_secret(
    authorization: Annotated[str | None, Header()] = None,
) -> None:
    """Verify RevenueCat webhook authorization header."""
    if not settings.revenuecat_webhook_secret:
        # If secret is not configured, skip verification (for development)
        return

    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Missing authorization header',
        )

    # RevenueCat sends: Authorization: Bearer <secret>
    if not authorization.startswith('Bearer '):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid authorization format',
        )

    secret = authorization.replace('Bearer ', '', 1)
    if secret != settings.revenuecat_webhook_secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid webhook secret',
        )


@router.post('/revenuecat', status_code=status.HTTP_200_OK)
async def revenuecat_webhook(
    request: Request,
    subscription_repository: Annotated[
        SubscriptionRepository,
        Depends(get_subscription_repository),
    ],
    user_repository: Annotated[
        UserRepository,
        Depends(get_user_repository),
    ],
    _: Annotated[None, Depends(verify_webhook_secret)],
) -> Literal[200]:
    """Handle RevenueCat webhook events.

    This endpoint receives webhook events from RevenueCat when subscription
    status changes (purchases, renewals, cancellations, etc.).

    Expected event types:
    - INITIAL_PURCHASE
    - RENEWAL
    - CANCELLATION
    - EXPIRATION
    - PRODUCT_CHANGE
    """
    try:
        event = await request.json()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Invalid JSON payload',
        ) from exc

    # Create subscription service with repositories
    subscription_service = SubscriptionService(
        subscription_repository=subscription_repository,
        user_repository=user_repository,
    )

    # Handle the webhook event
    await subscription_service.handle_webhook_event(event)

    return status.HTTP_200_OK
