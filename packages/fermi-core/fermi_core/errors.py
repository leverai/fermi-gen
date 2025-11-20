"""Custom exceptions for the fermi-core package."""


class UnitParsingError(ValueError):
    """Custom exception for pint unit parsing errors."""

    pass


class NoSnippetFoundError(Exception):
    """Raised when no snippet candidate can be extracted from search results."""

    pass


class LowConfidenceExtractionError(Exception):
    """Raised when extraction confidence is below threshold (default 0.8)."""

    pass


class SerpAPIError(Exception):
    """Raised when SerpAPI returns an error."""

    pass
