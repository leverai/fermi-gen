"""Domain exceptions for the game service.

These exceptions are raised by low-level write helpers (writers) and other
domain modules. They must be translated to HTTP-aware errors at the
application/use-case boundary.
"""


class DomainError(Exception):
    """Base class for domain-level errors."""


class NotFoundError(DomainError):
    """Raised when a requested entity does not exist."""


class StateConflictError(DomainError):
    """Raised when a state machine or invariant is violated (conflict)."""


class PermissionDeniedError(DomainError):
    """Raised when an action is not allowed for the current actor."""


class ValidationError(DomainError):
    """Raised when input/configuration is invalid for the attempted action."""
