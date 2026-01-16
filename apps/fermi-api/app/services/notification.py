"""Push notification service using Firebase Cloud Messaging.

Sends topic-based notifications to all subscribers of the 'dq_notifications' topic.
"""

import logging

import firebase_admin
from firebase_admin import messaging

logger = logging.getLogger(__name__)

# Topic all users subscribe to for DQ notifications
DQ_TOPIC = 'dq_notifications'


def _ensure_firebase_initialized() -> None:
    """Ensure Firebase Admin SDK is initialized."""
    if not firebase_admin._apps:
        firebase_admin.initialize_app()


def send_dq_activated_notification() -> None:
    """Send notification when DQ becomes active (12PM UTC)."""
    _ensure_firebase_initialized()

    message = messaging.Message(
        notification=messaging.Notification(
            title='Daily Question is Live! 🎯',
            body="Can you estimate today's answer?",
        ),
        data={
            'type': 'dq_activated',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        topic=DQ_TOPIC,
    )

    try:
        response = messaging.send(message)
        logger.info('DQ activated notification sent: %s', response)
    except Exception:
        logger.exception('Failed to send DQ activated notification')


def send_dq_results_ready_notification() -> None:
    """Send notification when DQ results are ready (after 2AM UTC close)."""
    _ensure_firebase_initialized()

    message = messaging.Message(
        notification=messaging.Notification(
            title='Results Are In! 📊',
            body="See how you ranked on yesterday's Daily Question.",
        ),
        data={
            'type': 'dq_results_ready',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        topic=DQ_TOPIC,
    )

    try:
        response = messaging.send(message)
        logger.info('DQ results ready notification sent: %s', response)
    except Exception:
        logger.exception('Failed to send DQ results ready notification')
