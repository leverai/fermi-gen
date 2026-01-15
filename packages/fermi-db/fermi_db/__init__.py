"""`fermi-db` package.

A dedicated Data Access Layer (DAL) for interacting with the
project's PostgreSQL database.
"""

from .dal import DatabaseClient
from .models import Fermi
from .repositories.fermi_repository import FermiRepository, FermiUpdate
from .repositories.seed_repository import SeedLight

__all__ = [
    'DatabaseClient',
    'Fermi',
    'FermiRepository',
    'FermiUpdate',
    'SeedLight',
    '__version__',
]

__version__ = '1.4.0'
