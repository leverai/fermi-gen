"""Contains the core functionality for the Fermi project."""

from .logging_utils import setup_logging
from .utils import utc_now, utcnow_naive

__all__ = [
    '__version__',
    'setup_logging',
    'utc_now',
]

__version__ = '0.2.0'
