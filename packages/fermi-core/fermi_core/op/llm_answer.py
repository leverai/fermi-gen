"""Function to get LLM answers for Fermi questions."""

import logging
from typing import Any, cast

from fermi_core.prompts import LLM_ANSWER_PROMPT
from fermi_core.schemas.llm_answer import LLMAnswerInput, LLMAnswerOutput
from fermi_core.utils import create_generic_chain

logger = logging.getLogger(__name__)


async def allm_answer_batch(
    questions: list[LLMAnswerInput],
    *,
    model: str = 'gpt-4o-mini',
    model_provider: str = 'openai',
    **model_kwargs: Any,
) -> list[LLMAnswerOutput | BaseException]:
    """Answer multiple Fermi questions using LLM concurrently.

    Uses LangChain's abatch to send a single API call for multiple inputs,
    significantly improving throughput.

    Returns exceptions in the result list (similar to asyncio.gather with
    return_exceptions=True) to maintain 1:1 correspondence between inputs
    and outputs.

    Args:
        questions: List of LLMAnswerInput with question text and optional units_set
        model: LLM model to use (e.g., 'gpt-5.1', 'gpt-5-mini', 'gpt-5-nano')
        model_provider: Model provider (e.g., 'openai')
        **model_kwargs: Additional model configuration (e.g., service_tier='flex')

    Returns:
        List of LLMAnswerOutput or BaseException, one for each question in order

    """
    if not questions:
        return []

    # Create chain once for all questions
    chain = create_generic_chain(
        model=model,
        model_provider=model_provider,
        prompt=LLM_ANSWER_PROMPT,
        output_schema=LLMAnswerOutput,
        input_schema=LLMAnswerInput,
        **model_kwargs,
    )

    logger.info(
        f'Answering {len(questions)} questions using model {model} (batch mode)...',
    )

    # Build input dicts for the prompt template
    chain_inputs = []
    for q in questions:
        units_str = (
            f'**Unit Set:** {q["units_set"]}'
            if q['units_set']
            else '(Dimensionless question - no unit required)'
        )
        chain_inputs.append(
            {
                'question': q['question'],
                'units_info': units_str,
            },
        )

    # Batch invoke - sends all requests concurrently
    # return_exceptions=True maintains 1:1 correspondence with inputs
    responses = cast(
        list[LLMAnswerOutput | BaseException],
        await chain.abatch(chain_inputs, return_exceptions=True),
    )

    # Log any failures
    failure_count = sum(1 for r in responses if isinstance(r, BaseException))
    if failure_count > 0:
        logger.warning(
            f'{failure_count}/{len(responses)} LLM answer requests failed',
        )

    logger.info(
        f'Answered {len(responses) - failure_count}/{len(questions)} questions',
    )
    return responses
