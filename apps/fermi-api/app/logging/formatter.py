"""Log formatters for structured logging compatible with Google Cloud Logging.

This module provides formatters that work with OTel's LoggingInstrumentor,
which automatically injects trace/span IDs into all log records.
"""

import json
import logging
import os
from datetime import UTC, datetime
from typing import Any, ClassVar


class CloudLoggingFormatter(logging.Formatter):
    """JSON formatter compatible with Google Cloud Logging.

    Outputs logs as JSON objects with Cloud Logging special fields for
    severity, trace correlation, and structured payloads.

    OTel's LoggingInstrumentor injects otelTraceID, otelSpanID, and
    otelTraceSampled into each LogRecord automatically.

    See: https://cloud.google.com/logging/docs/structured-logging
    """

    # Cloud Logging severity levels
    SEVERITY_MAP: ClassVar[dict[int, str]] = {
        logging.DEBUG: 'DEBUG',
        logging.INFO: 'INFO',
        logging.WARNING: 'WARNING',
        logging.ERROR: 'ERROR',
        logging.CRITICAL: 'CRITICAL',
    }

    def __init__(self, service_name: str = 'fermi-api') -> None:
        """Initialize the formatter.

        Args:
            service_name: Name of the service for log labels.

        """
        super().__init__()
        self.service_name = service_name
        self.project_id = os.environ.get('GOOGLE_CLOUD_PROJECT')

    def format(self, record: logging.LogRecord) -> str:
        """Format the log record as a JSON string.

        Args:
            record: The log record to format.

        Returns:
            JSON-formatted log string.

        """
        # Build the log entry
        log_entry: dict[str, Any] = {
            'severity': self.SEVERITY_MAP.get(record.levelno, 'DEFAULT'),
            'message': record.getMessage(),
            'timestamp': datetime.now(UTC).isoformat(),
        }

        # Get OTel trace info injected by LoggingInstrumentor
        trace_id = getattr(record, 'otelTraceID', '0')
        span_id = getattr(record, 'otelSpanID', '0')
        trace_sampled = getattr(record, 'otelTraceSampled', False)

        # Add Cloud Logging trace correlation if trace_id is present
        if trace_id and trace_id != '0' and self.project_id:
            log_entry['logging.googleapis.com/trace'] = (
                f'projects/{self.project_id}/traces/{trace_id}'
            )
            if span_id and span_id != '0':
                log_entry['logging.googleapis.com/spanId'] = span_id
            log_entry['logging.googleapis.com/trace_sampled'] = trace_sampled

        # Add source location for debugging
        log_entry['logging.googleapis.com/sourceLocation'] = {
            'file': record.pathname,
            'line': record.lineno,
            'function': record.funcName,
        }

        # Add exception info if present
        if record.exc_info:
            log_entry['exception'] = self.formatException(record.exc_info)

        return json.dumps(log_entry, default=str)


class LocalDevFormatter(logging.Formatter):
    """Human-readable formatter for local development.

    Outputs colored, structured logs that are easier to read during development.
    Includes OTel trace/span IDs when available.
    """

    COLORS: ClassVar[dict[str, str]] = {
        'DEBUG': '\033[36m',  # Cyan
        'INFO': '\033[32m',  # Green
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',  # Red
        'CRITICAL': '\033[35m',  # Magenta
        'RESET': '\033[0m',
    }

    def format(self, record: logging.LogRecord) -> str:
        """Format the log record for local development.

        Args:
            record: The log record to format.

        Returns:
            Formatted log string with colors.

        """
        color = self.COLORS.get(record.levelname, '')
        reset = self.COLORS['RESET']

        # Build context string from OTel and wide_event
        context_parts = []

        # Get trace/span from OTel
        span_id = getattr(record, 'otelSpanID', None)
        if span_id and span_id != '0':
            context_parts.append(f'span={span_id[:8]}')

        context_str = ' '.join(context_parts)
        if context_str:
            context_str = f' [{context_str}]'

        # Format the message
        timestamp = datetime.now(UTC).strftime('%H:%M:%S.%f')[:-3]
        formatted = (
            f'{timestamp} {color}{record.levelname:8}{reset}'
            f'{context_str} {record.getMessage()}'
        )

        # Add exception if present
        if record.exc_info:
            formatted += '\n' + self.formatException(record.exc_info)

        return formatted
