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
    """Raised when smart search cannot build a full game from eligible questions.

    Smart search does not apply a relevance cutoff, so this indicates corpus
    availability rather than a query the user should rewrite.
    """

    def __init__(self, query: str, found: int) -> None:
        """Capture the query and the number of eligible questions found."""
        self.query = query
        self.found = found
        super().__init__(
            f'Only {found} question(s) matched the search {query!r}',
        )
