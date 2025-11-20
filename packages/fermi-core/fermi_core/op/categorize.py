"""Function to categorize Fermi questions."""

import logging
from typing import Any, TypedDict, cast

from fermi_core.prompts import CATEGORIZE_PROMPT
from fermi_core.schemas.category import QuestionCategory
from fermi_core.utils import create_generic_chain

logger = logging.getLogger(__name__)


class CategorizeInput(TypedDict):
    """Input for the categorize chain."""

    question: str


async def acategorize_batch(
    questions: list[str],
    *,
    model: str = 'gpt-4o-mini',
    model_provider: str = 'openai',
    **model_kwargs: Any,
) -> list[QuestionCategory | BaseException]:
    """Categorize multiple Fermi questions concurrently.

    Uses LangChain's abatch to send a single API call for multiple inputs,
    significantly improving throughput.

    Returns exceptions in the result list (similar to asyncio.gather with
    return_exceptions=True) to maintain 1:1 correspondence between inputs
    and outputs.

    Args:
        questions: List of question texts to categorize
        model: LLM model to use
        model_provider: Model provider (e.g., 'openai')
        **model_kwargs: Additional model configuration

    Returns:
        List of QuestionCategory or BaseException, one for each question in order

    """
    if not questions:
        return []

    # Create chain once for all questions
    chain = create_generic_chain(
        model=model,
        model_provider=model_provider,
        prompt=CATEGORIZE_PROMPT,
        output_schema=QuestionCategory,
        input_schema=CategorizeInput,
        **model_kwargs,
    )

    logger.info(
        f'Categorizing {len(questions)} questions using model {model} (batch mode)...',
    )

    # Prepare input states for all questions
    categorize_inputs = [CategorizeInput(question=q) for q in questions]

    # Batch invoke - sends all requests concurrently
    # return_exceptions=True maintains 1:1 correspondence with inputs
    responses = cast(
        list[QuestionCategory | BaseException],
        await chain.abatch(categorize_inputs, return_exceptions=True),
    )

    # Log any failures
    failure_count = sum(1 for r in responses if isinstance(r, BaseException))
    if failure_count > 0:
        logger.warning(
            f'{failure_count}/{len(responses)} categorization requests failed',
        )

    logger.info(
        f'Categorized {len(responses) - failure_count}/{len(questions)} questions',
    )
    return responses
