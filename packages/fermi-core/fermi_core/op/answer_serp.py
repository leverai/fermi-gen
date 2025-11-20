"""Answer Fermi questions using SerpAPI and LLM agents."""

import asyncio
import logging
import os
from typing import Any

from serpapi import GoogleSearch

from fermi_core.errors import (
    LowConfidenceExtractionError,
    NoSnippetFoundError,
    SerpAPIError,
)
from fermi_core.prompts import (
    EXTRACT_INFO_PROMPT,
    SELECT_LOCATION_PROMPT,
)
from fermi_core.schemas.answer import ExtractInfoState
from fermi_core.schemas.serp import (
    ExtractedInfo,
    LocationSelection,
    SerpAIOverviewX,
    SerpAnswer,
    SerpSearchResult,
    SnippetCandidate,
)
from fermi_core.utils import create_generic_chain

logger = logging.getLogger(__name__)


async def asearch_google(
    query: str,
    gl: str = 'us',
) -> SerpSearchResult:
    """Execute a standard Google search using SerpAPI.

    Uses SERP_API_KEY environment variable (required).
    Always uses hl="en" for language and engine="google".

    Risk mitigation:
    - Truncates query to 500 chars (SerpAPI limit)
    - Raises SerpAPIError on API errors

    Args:
        query: The search query
        gl: Location/country code (default: "us")

    Returns:
        SerpSearchResult with ai_overview and/or related_questions

    Raises:
        SerpAPIError: If SerpAPI returns an error or API key is missing

    """
    api_key = os.environ.get('SERP_API_KEY')
    if not api_key:
        raise SerpAPIError('SERP_API_KEY environment variable not set')

    # Truncate query to SerpAPI limit
    truncated_query = query[:500]

    # Build search params for standard Google search
    params = {
        'q': truncated_query,
        'gl': gl,
        'hl': 'en',
        'engine': 'google',
        'api_key': api_key,
    }

    try:
        # Run search in executor to avoid blocking
        loop = asyncio.get_event_loop()
        search = await loop.run_in_executor(
            None,
            lambda: GoogleSearch(params).get_dict(),
        )

        # Check for error in response
        if 'error' in search:
            raise SerpAPIError(f'SerpAPI error: {search["error"]}')

        # Convert to our schema
        return SerpSearchResult.model_validate(search)

    except Exception as exc:
        if isinstance(exc, SerpAPIError):
            raise
        logger.error(f'Google search failed: {exc}')
        raise SerpAPIError(f'Google search failed: {exc}') from exc


async def asearch_google_ai_overview(
    page_token: str,
) -> SerpSearchResult:
    """Execute a Google AI Overview extra request using SerpAPI.

    This is used when the initial search returns an AI Overview that requires
    an additional request (indicated by page_token field).

    Uses SERP_API_KEY environment variable (required).
    Uses engine="google_ai_overview".

    Args:
        page_token: The page token from initial search's AI Overview

    Returns:
        SerpSearchResult with the full AI Overview

    Raises:
        SerpAPIError: If SerpAPI returns an error or API key is missing

    """
    api_key = os.environ.get('SERP_API_KEY')
    if not api_key:
        raise SerpAPIError('SERP_API_KEY environment variable not set')

    # Build search params for AI Overview engine
    params = {
        'page_token': page_token,
        'engine': 'google_ai_overview',
        'api_key': api_key,
    }

    try:
        # Run search in executor to avoid blocking
        loop = asyncio.get_event_loop()
        search = await loop.run_in_executor(
            None,
            lambda: GoogleSearch(params).get_dict(),
        )

        # Check for error in response
        if 'error' in search:
            raise SerpAPIError(f'SerpAPI error: {search["error"]}')

        # Convert to our schema
        return SerpSearchResult.model_validate(search)

    except Exception as exc:
        if isinstance(exc, SerpAPIError):
            raise
        logger.error(f'Google AI Overview search failed: {exc}')
        raise SerpAPIError(f'Google AI Overview search failed: {exc}') from exc


async def aextract_snippet_candidate(
    search_result: SerpSearchResult,
) -> SnippetCandidate:
    """Extract the best snippet candidate from search results.

    Priority:
    1. AI Overview snippet (if available and ready)
    2. AI Overview via extra request (if isinstance SerpAIOverviewX)
    3. First related question's snippet (fallback)

    Args:
        search_result: The search result from SerpAPI

    Returns:
        SnippetCandidate with snippet, metadata, and source

    Raises:
        NoSnippetFoundError: If no suitable snippet found

    """
    if not search_result.ai_overview:
        raise NoSnippetFoundError('No AI overview found in search results')

    # Get actual AI overview if a page token was returned
    ai_overview = search_result.ai_overview
    if isinstance(ai_overview, SerpAIOverviewX):
        logger.info('AI Overview requires extra request, fetching...')
        extra_result = await asearch_google_ai_overview(ai_overview.page_token)
        if not extra_result.ai_overview or isinstance(
            extra_result.ai_overview,
            SerpAIOverviewX,
        ):
            raise NoSnippetFoundError('Extra request did not return valid AI overview')
        ai_overview = extra_result.ai_overview

    if not ai_overview.snippet:
        # Try to get snippet from first related question
        if not search_result.related_questions:
            raise NoSnippetFoundError('No related questions found in search results')
        first_related = search_result.related_questions[0]
        if not first_related.snippet:
            raise NoSnippetFoundError('No snippet found in first related question')
        return SnippetCandidate(
            snippet=first_related.snippet,
            metadata=first_related.model_dump(),
            source='related_question',
        )

    return SnippetCandidate(
        snippet=ai_overview.snippet,
        metadata=ai_overview.model_dump(),
        source='ai_overview',
    )


async def aget_questions_answers_serp(
    questions: list[str],
    *,
    location_model: str = 'gpt-4o-mini',
    extraction_model: str = 'gpt-4o',
    model_provider: str = 'openai',
    confidence_threshold: float = 0.8,
    **model_kwargs: Any,
) -> list[SerpAnswer | BaseException]:
    """Answer a batch of Fermi questions using SerpAPI.

    Uses LangChain's abatch for LLM operations (network efficient).
    Uses asyncio.gather for non-Runnable async operations (SerpAPI calls).

    Args:
        questions: List of Fermi questions to answer
        location_model: Model for selecting search locations (default: gpt-4o-mini)
        extraction_model: Model for extracting and validating answers (default: gpt-4o)
        model_provider: Provider for all models (default: openai)
        confidence_threshold: Minimum confidence to accept answer (default: 0.8)
        **model_kwargs: Additional kwargs passed to all models

    Returns:
        List where each element is either SerpAnswer or an Exception.
        List length matches input questions length.

    """
    # Initialize results list - same length as questions
    results: dict[int, SerpAnswer | BaseException] = {}
    n_questions = len(questions)

    # Step 1: Batch location selection with abatch (uses location_model)
    location_chain = create_generic_chain(
        model=location_model,
        model_provider=model_provider,
        prompt=SELECT_LOCATION_PROMPT,
        output_schema=LocationSelection,
        input_schema=dict,
        **model_kwargs,
    )
    locations = await location_chain.abatch(
        [{'question': q} for q in questions],
        return_exceptions=True,
    )

    # Track which indices have valid locations
    valid_with_location: list[tuple[int, LocationSelection]] = []
    for idx, location in enumerate[LocationSelection](locations):
        if isinstance(location, BaseException):
            results[idx] = location
        else:
            valid_with_location.append((idx, location))

    if not valid_with_location:
        return [results[i] for i in range(n_questions)]  # All failed location selection

    logger.info(
        f'Location selection: {len(valid_with_location)}/{len(questions)} succeeded',
    )

    # Step 2: Batch SerpAPI searches (asyncio.gather - not a Runnable)
    search_results = await asyncio.gather(
        *[
            asearch_google(query=questions[idx], gl=loc.gl)
            for idx, loc in valid_with_location
        ],
        return_exceptions=True,
    )

    # Track which have valid search results
    valid_with_search: list[tuple[int, SerpSearchResult]] = []
    for (idx, _), search_result in zip(
        valid_with_location,
        search_results,
        strict=True,
    ):
        if isinstance(search_result, BaseException):
            results[idx] = search_result
        else:
            valid_with_search.append((idx, search_result))

    if not valid_with_search:
        return [results[i] for i in range(n_questions)]  # All failed search

    logger.info(
        f'SerpAPI searches: {len(valid_with_search)}/{len(questions)} succeeded',
    )

    # Step 3: Batch snippet extraction (asyncio.gather)
    snippet_candidates = await asyncio.gather(
        *[
            aextract_snippet_candidate(search_result)
            for _, search_result in valid_with_search
        ],
        return_exceptions=True,
    )

    # Track which have valid snippets
    valid_with_snippet: list[tuple[int, SnippetCandidate]] = []
    for (idx, _), snippet in zip(
        valid_with_search,
        snippet_candidates,
        strict=False,
    ):
        if isinstance(snippet, BaseException):
            results[idx] = snippet
        else:
            valid_with_snippet.append((idx, snippet))

    if not valid_with_snippet:
        return [results[i] for i in range(n_questions)]  # All failed snippet extraction

    logger.info(
        f'Snippet extraction: {len(valid_with_snippet)}/{len(questions)} succeeded',
    )

    # Step 4: Batch info extraction with abatch (uses extraction_model)
    # Note: Extraction also validates via confidence scoring
    extraction_chain = create_generic_chain(
        model=extraction_model,
        model_provider=model_provider,
        prompt=EXTRACT_INFO_PROMPT,
        output_schema=ExtractedInfo,
        input_schema=ExtractInfoState,
        **model_kwargs,
    )
    extracted_infos = await extraction_chain.abatch(
        [
            ExtractInfoState(
                question=questions[idx],
                paragraph=snippet.snippet,
            )
            for idx, snippet in valid_with_snippet
        ],
        return_exceptions=True,
    )

    success_count = len(
        [e for e in extracted_infos if not isinstance(e, BaseException)],
    )
    logger.info(f'Info extraction: {success_count}/{len(questions)} succeeded')

    # Step 5: Build SerpAnswer objects, checking confidence >= threshold
    for (idx, snippet), extracted_info in zip(
        valid_with_snippet,
        extracted_infos,
        strict=False,
    ):
        if isinstance(extracted_info, BaseException):
            results[idx] = extracted_info
        elif extracted_info.confidence < confidence_threshold:
            results[idx] = LowConfidenceExtractionError(
                f'Confidence {extracted_info.confidence} '
                f'below threshold {confidence_threshold}',
            )
        else:
            # Success! Build SerpAnswer
            number, unit = extracted_info.to_base_unit()
            results[idx] = SerpAnswer(
                number=number,
                unit=unit,
                snippet=snippet.snippet,
                used_ai_overview=(snippet.source == 'ai_overview'),
                metadata=snippet.metadata,
                confidence=extracted_info.confidence,
            )

    # final_success = len([r for r in results if isinstance(r, SerpAnswer)])
    final_success = sum(1 for r in results.values() if isinstance(r, SerpAnswer))
    logger.info(f'Final success: {final_success}/{len(questions)} questions answered')

    return [results[i] for i in range(n_questions)]
