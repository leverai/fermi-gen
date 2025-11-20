"""Function to assess difficulty of Fermi questions."""

import logging
from typing import Any, TypedDict, cast

from fermi_core.prompts import DIFFICULTY_PROMPT
from fermi_core.schemas.difficulty import QuestionDifficulty
from fermi_core.utils import create_generic_chain

logger = logging.getLogger(__name__)


class DifficultyInput(TypedDict):
    """Input for the difficulty assessment chain."""

    question: str


async def adifficulty_batch(
    questions: list[str],
    *,
    model: str = 'gpt-4o-mini',
    model_provider: str = 'openai',
    **model_kwargs: Any,
) -> list[QuestionDifficulty | BaseException]:
    """Assess difficulty for multiple Fermi questions concurrently.

    Uses LangChain's abatch to send a single API call for multiple inputs,
    significantly improving throughput.

    Returns exceptions in the result list (similar to asyncio.gather with
    return_exceptions=True) to maintain 1:1 correspondence between inputs
    and outputs.

    Args:
        questions: List of question texts to assess
        model: LLM model to use
        model_provider: Model provider (e.g., 'openai')
        **model_kwargs: Additional model configuration

    Returns:
        List of QuestionDifficulty or BaseException, one for each question in order

    """
    if not questions:
        return []

    # Create chain once for all questions
    chain = create_generic_chain(
        model=model,
        model_provider=model_provider,
        prompt=DIFFICULTY_PROMPT,
        output_schema=QuestionDifficulty,
        input_schema=DifficultyInput,
        **model_kwargs,
    )

    logger.info(
        f'Assessing difficulty for {len(questions)} questions '
        f'using model {model} (batch mode)...',
    )

    # Prepare input states for all questions
    difficulty_inputs = [DifficultyInput(question=q) for q in questions]

    # Batch invoke - sends all requests concurrently
    # return_exceptions=True maintains 1:1 correspondence with inputs
    responses = cast(
        list[QuestionDifficulty | BaseException],
        await chain.abatch(difficulty_inputs, return_exceptions=True),
    )

    # Log any failures
    failure_count = sum(1 for r in responses if isinstance(r, BaseException))
    if failure_count > 0:
        logger.warning(
            f'{failure_count}/{len(responses)} difficulty assessment requests failed',
        )

    logger.info(
        f'Assessed difficulty for '
        f'{len(responses) - failure_count}/{len(questions)} questions',
    )
    return responses
