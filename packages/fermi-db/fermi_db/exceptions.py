"""Custom exceptions for the fermi-db package."""

from typing import Any


class DalError(Exception):
    """Base exception for DAL-related errors."""


class ConnectionError(DalError):
    """Raised when a database connection fails."""


class QuestionNotFoundError(DalError):
    """Raised when a question is not found in the database."""

    def __init__(self, uid: Any):
        """Initialize the exception."""
        super().__init__(f'Question with uid {uid} not found')
