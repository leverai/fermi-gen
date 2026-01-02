"""Pipeline stage constants for structured logging."""


class Stage:
    """Pipeline stage identifiers for log filtering."""

    GPT_ANSWER = 'gpt_answer'
    GEMINI_FLASH_ANSWER = 'gemini_flash_answer'
    SERP_ANSWER = 'serp_answer'
    ENRICHMENT = 'enrichment'
    SYNC = 'sync'
