"""Webhook endpoints for external services."""

import logging
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
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode

import app.logging.attributes as api_attrs
from app.api.v1.dependencies import (
    get_subscription_repository,
    get_user_repository,
)
from app.core.config import settings
from app.services.subscription import SubscriptionService

router = APIRouter()
logger = logging.getLogger(__name__)


async def verify_webhook_secret(
    authorization: Annotated[str | None, Header()] = None,
) -> None:
    """Verify RevenueCat webhook authorization header."""
    if not settings.revenuecat_webhook_secret:
        # Secret not configured - reject request
        # Set REVENUECAT_WEBHOOK_SECRET env var to enable webhooks
        logger.error(
            'REVENUECAT_WEBHOOK_SECRET not configured - rejecting webhook request',
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail='Webhook endpoint not configured',
        )

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
    - TRANSFER
    - RENEWAL
    - CANCELLATION
    - EXPIRATION
    - PRODUCT_CHANGE
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, revenuecat_webhook.__qualname__)

    try:
        payload = await request.json()
    except Exception as exc:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(exc)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='Invalid JSON payload',
        ) from exc

    # Enrich span with webhook info
    event_data = payload.get('event', payload)
    span.set_attribute(api_attrs.WEBHOOK_EVENT_TYPE, event_data.get('type', ''))
    span.set_attribute(api_attrs.WEBHOOK_APP_USER_ID, event_data.get('app_user_id', ''))
    span.set_attribute(api_attrs.WEBHOOK_PRODUCT_ID, event_data.get('product_id', ''))

    # Create subscription service with repositories
    subscription_service = SubscriptionService(
        subscription_repository=subscription_repository,
        user_repository=user_repository,
    )

    # Handle the webhook event
    try:
        await subscription_service.handle_webhook_event(payload)
    except Exception as ex:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(ex)
        raise

    return status.HTTP_200_OK
