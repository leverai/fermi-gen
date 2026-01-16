"""OpenTelemetry setup for fermi-api.

This module initializes OpenTelemetry for tracing and log correlation.
It replaces the custom context system with OTel span attributes.
"""

import logging
import os
from typing import Any

from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, SERVICE_VERSION, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

from app.version import __version__


def setup_otel(
    service_name: str = 'fermi-api',
    *,
    use_gcp_exporter: bool | None = None,
) -> None:
    """Initialize OpenTelemetry tracing and logging instrumentation.

    Args:
        service_name: Name of the service for traces.
        use_gcp_exporter: If True, export traces to GCP Cloud Trace.
                          If False, use console exporter for local dev.
                          If None, auto-detect based on K_SERVICE env var.

    """
    # Auto-detect environment
    if use_gcp_exporter is None:
        use_gcp_exporter = 'K_SERVICE' in os.environ

    # Get service name from Cloud Run if available
    service_name = os.environ.get('K_SERVICE', service_name)

    # Create resource with service info
    resource = Resource.create(
        attributes={
            SERVICE_NAME: service_name,
            SERVICE_VERSION: __version__,
        },
    )

    # Set up tracer provider
    provider = TracerProvider(resource=resource)

    # Add span processor with appropriate exporter
    if use_gcp_exporter:
        try:
            from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter

            exporter = CloudTraceSpanExporter()
            provider.add_span_processor(BatchSpanProcessor(exporter))
            logging.info('OpenTelemetry configured with GCP Cloud Trace exporter')
        except Exception:
            logging.exception('Failed to initialize GCP Cloud Trace exporter')
            # Fall back to console exporter
            provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    else:
        # Local dev: use console exporter (or no-op for cleaner logs)
        # Using no span processor means spans are created but not exported
        logging.debug(
            'OpenTelemetry configured for local development (no trace export)',
        )

    # Set as global tracer provider
    trace.set_tracer_provider(provider)

    # Instrument logging to add trace/span IDs to all log records
    LoggingInstrumentor().instrument(set_logging_format=False)


def instrument_fastapi(app: Any) -> None:
    """Instrument a FastAPI application with OpenTelemetry.

    This adds automatic span creation for all HTTP requests.

    To exclude URLs from tracing, set the OTEL_PYTHON_FASTAPI_EXCLUDED_URLS
    environment variable to a comma-delimited list of regex patterns.
    Example: OTEL_PYTHON_FASTAPI_EXCLUDED_URLS="health,/health,/api/v1/health"

    Args:
        app: The FastAPI application instance.

    """
    FastAPIInstrumentor.instrument_app(app)
