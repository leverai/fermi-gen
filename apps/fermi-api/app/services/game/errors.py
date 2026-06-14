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


class SearchEmbeddingError(DomainError):
    """Raised when embedding a smart-search query fails (e.g. OpenAI down/timeout).

    This is a transient failure: the same query may succeed on retry, so it maps
    to a retryable 503 at the HTTP boundary.
    """


class SearchNoResultsError(DomainError):
    """Raised when a smart-search query matches fewer than the required minimum.

    The embed succeeded, but the similarity floor left too few questions to build
    a full game. This is *not* retryable for the same query: the user must broaden
    or change it. Maps to a non-retryable 4xx at the HTTP boundary.
    """

    def __init__(self, query: str, found: int) -> None:
        """Capture the offending query and how many matches cleared the floor."""
        self.query = query
        self.found = found
        super().__init__(
            f'Only {found} question(s) matched the search {query!r}',
        )
