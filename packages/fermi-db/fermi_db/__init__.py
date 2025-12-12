"""`fermi-db` package.

A dedicated Data Access Layer (DAL) for interacting with the
project's PostgreSQL database.
"""

from .dal import DatabaseClient
from .repositories.seed_repository import SeedLight

__all__ = [
    'DatabaseClient',
    'SeedLight',
    '__version__',
]

__version__ = '0.1.0'
