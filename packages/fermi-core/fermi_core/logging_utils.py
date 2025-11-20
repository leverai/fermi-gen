"""Logging utilities for the fermi-gen project."""

import logging
import os

from google.cloud.logging import Client


def setup_logging(level: int = logging.INFO) -> None:
    """Set up logging for the application. Function automatically detects if
    running in a Google Cloud environment and uses Google Cloud Logging if so.

    Args:
        level: The logging level to use.

    """
    if 'K_SERVICE' in os.environ:
        # Use Google Cloud Logging when running in a Google Cloud environment
        client = Client()
        client.setup_logging()
        logging.info('Google Cloud Logging enabled.')
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    )
