"""Pipeline stage constants for structured logging."""


class Stage:
    """Pipeline stage identifiers for log filtering."""

    LLM_ANSWER = 'llm_answer'
    SERP_ANSWER = 'serp_answer'
    ENRICHMENT = 'enrichment'
    SYNC = 'sync'
