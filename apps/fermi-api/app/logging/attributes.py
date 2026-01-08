"""Custom span attribute constants for fermi-api.

Following OpenTelemetry semantic conventions naming pattern
(namespace.entity.attribute). All custom application attributes use 'app.' prefix.

Usage:
    from opentelemetry import trace
    from app.logging.attributes import ACTION, USER_ID

    span = trace.get_current_span()
    span.set_attribute(ACTION, 'dq_start')
    span.set_attribute(USER_ID, user.id)
"""

from typing import Final

# =============================================================================
# Business context
# =============================================================================

ACTION: Final = 'action'
"""The action being performed (e.g., 'dq_start', 'revenuecat_webhook')."""

QUERY_PARAMS: Final = 'query_params'

SUCCESS: Final = 'success'
"""Whether the operation succeeded."""

ERROR_TYPE: Final = 'error.type'
"""Type/name of error that occurred."""

# =============================================================================
# User context
# =============================================================================

USER_ID: Final = 'user.id'
"""Internal user ID from database."""

FIREBASE_UID: Final = 'user.firebase_uid'
"""Firebase authentication UID."""

USER_TIER: Final = 'user.tier'
"""User tier (e.g., 'free', 'pro')."""

# =============================================================================
# Daily Question context
# =============================================================================

QUESTION_UID: Final = 'dq.question_uid'
"""Daily question unique ID."""

DQ_CATEGORY: Final = 'dq.category'
"""Daily question category."""

DQ_SUBMITTED: Final = 'dq.submitted'
"""Whether the DQ answer was submitted."""

DQ_SCORE: Final = 'dq.score'
"""Score for the DQ answer."""

DQ_DATE: Final = 'dq.date'
"""Daily question date (YYYY-MM-DD)."""

# =============================================================================
# Game context (Party mode)
# =============================================================================

GAME_ID: Final = 'game.id'
"""Game unique ID."""

GAME_STATE: Final = 'game.state'
"""Current game state (e.g., 'LOBBY', 'PLAYING')."""

GAME_PLAYER_COUNT: Final = 'game.player_count'
"""Number of players in the game."""

GAME_QUESTION_UID: Final = 'game.question_uid'
"""Current question UID."""

GAME_QUESTION_ORDER: Final = 'game.question_order'
"""Current question order/number."""

# =============================================================================
# Webhook context
# =============================================================================

WEBHOOK_EVENT_TYPE: Final = 'webhook.event_type'
"""Type of webhook event (e.g., 'INITIAL_PURCHASE', 'RENEWAL')."""

WEBHOOK_APP_USER_ID: Final = 'webhook.app_user_id'
"""App user ID from webhook payload."""

WEBHOOK_PRODUCT_ID: Final = 'webhook.product_id'
"""Product ID from webhook payload."""
