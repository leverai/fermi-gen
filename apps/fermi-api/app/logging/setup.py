"""Logging setup for the fermi-api service.

Provides a setup function that configures OpenTelemetry and
structured logging for GCP or local development.
"""

import logging
import os
import sys

from app.logging.formatter import CloudLoggingFormatter, LocalDevFormatter
from app.logging.otel import setup_otel


def setup_api_logging(
    level: int = logging.INFO,
    service_name: str = 'fermi-api',
    *,
    use_json: bool | None = None,
) -> None:
    """Set up structured logging and OpenTelemetry for the API.

    Configures:
    1. OpenTelemetry tracing and log instrumentation
    2. Python logging with appropriate formatter (JSON for GCP, text for local)

    Args:
        level: The logging level to use.
        service_name: Name of the service for log labels.
        use_json: Force JSON format (True) or text format (False).
                  If None, auto-detect based on environment.

    """
    # Auto-detect format based on environment
    if use_json is None:
        # Use JSON in Cloud Run or when explicitly requested
        use_json = 'K_SERVICE' in os.environ

    service_name = os.environ.get('K_SERVICE', service_name)

    # Initialize OpenTelemetry
    setup_otel(service_name=service_name)

    # Get the root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Remove existing handlers to avoid duplicates
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    # Create handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(level)

    # Set formatter based on environment
    if use_json:
        formatter = CloudLoggingFormatter(service_name=service_name)
    else:
        formatter = LocalDevFormatter()

    handler.setFormatter(formatter)
    root_logger.addHandler(handler)

    # Set levels for noisy third-party loggers
    logging.getLogger('uvicorn.access').setLevel(logging.WARNING)
    logging.getLogger('uvicorn.error').setLevel(logging.WARNING)
    logging.getLogger('httpcore').setLevel(logging.WARNING)
    logging.getLogger('httpx').setLevel(logging.WARNING)
    logging.getLogger('google').setLevel(logging.WARNING)
    logging.getLogger('opentelemetry').setLevel(logging.WARNING)

    logging.info(
        'Logging configured',
        extra={
            'format': 'json' if use_json else 'text',
            'level': logging.getLevelName(level),
            'service': service_name,
        },
    )
