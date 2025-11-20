"""Custom exceptions for the fermi-api package."""


class AuthError(Exception):
    """Base exception for authentication errors."""

    pass


class InvalidFirebaseTokenError(AuthError):
    """Raised when an invalid Firebase token is provided."""

    pass


class InvalidJWTError(AuthError):
    """Raised when an invalid JWT is provided."""

    pass
