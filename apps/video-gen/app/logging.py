"""Logging setup for video-gen Cloud Run job.

Provides structured JSON logging for GCP Cloud Logging integration,
with human-readable output for local development.
"""

import json
import logging
import os
import sys
from datetime import UTC, datetime
from typing import Any, ClassVar


class CloudLoggingFormatter(logging.Formatter):
    """JSON formatter compatible with Google Cloud Logging."""

    SEVERITY_MAP: ClassVar[dict[int, str]] = {
        logging.DEBUG: 'DEBUG',
        logging.INFO: 'INFO',
        logging.WARNING: 'WARNING',
        logging.ERROR: 'ERROR',
        logging.CRITICAL: 'CRITICAL',
    }

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON for Cloud Logging."""
        log_entry: dict[str, Any] = {
            'severity': self.SEVERITY_MAP.get(record.levelno, 'DEFAULT'),
            'message': record.getMessage(),
            'timestamp': datetime.now(UTC).isoformat(),
            'logging.googleapis.com/sourceLocation': {
                'file': record.pathname,
                'line': record.lineno,
                'function': record.funcName,
            },
        }

        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)

        return json.dumps(log_entry, default=str)


class LocalDevFormatter(logging.Formatter):
    """Human-readable formatter for local development."""

    COLORS: ClassVar[dict[str, str]] = {
        'DEBUG': '\033[36m',  # Cyan
        'INFO': '\033[32m',  # Green
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',  # Red
        'CRITICAL': '\033[35m',  # Magenta
        'RESET': '\033[0m',
    }

    def format(self, record: logging.LogRecord) -> str:
        """Format log record with colors for local development."""
        color = self.COLORS.get(record.levelname, '')
        reset = self.COLORS['RESET']
        timestamp = datetime.now(UTC).strftime('%H:%M:%S.%f')[:-3]

        formatted = (
            f'{timestamp} {color}{record.levelname:8}{reset} {record.getMessage()}'
        )

        if record.exc_info:
            formatted += '\n' + self.formatException(record.exc_info)

        return formatted


def setup_logging(level: int = logging.INFO) -> None:
    """Set up logging for the video-gen job.

    Uses JSON format in Cloud Run (detected via K_SERVICE env var),
    human-readable format locally.
    """
    use_json = 'K_SERVICE' in os.environ
    if use_json:
        import google.cloud.logging

        client = google.cloud.logging.Client()
        client.setup_logging()

    root_logger = logging.getLogger()
    root_logger.setLevel(level)

    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(level)

    if use_json:
        handler.setFormatter(CloudLoggingFormatter())
    else:
        handler.setFormatter(LocalDevFormatter())

    root_logger.addHandler(handler)

    # Quiet noisy loggers
    logging.getLogger('google').setLevel(logging.WARNING)
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('moviepy').setLevel(logging.WARNING)

    logging.info(
        'Logging configured',
        extra={'format': 'json' if use_json else 'text'},
    )
