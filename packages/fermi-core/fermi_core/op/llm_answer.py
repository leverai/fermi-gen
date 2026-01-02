"""Function to get LLM answers for Fermi questions."""

import logging
from typing import Any, cast

from fermi_core.prompts import LLM_ANSWER_PROMPT
from fermi_core.schemas.llm_answer import (
    LLMAnswerInput,
    LLMAnswerOutput,
    LLMChainOutput,
)
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
        questions: List of LLMAnswerInput with question text and optional answer unit
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
        output_schema=LLMChainOutput,
        input_schema=LLMAnswerInput,
        **model_kwargs,
    )

    logger.info(
        f'Answering {len(questions)} questions using model {model} (batch mode)...',
    )

    # Batch invoke - sends all requests concurrently
    # return_exceptions=True maintains 1:1 correspondence with inputs
    responses = cast(
        list[LLMChainOutput | BaseException | None],
        await chain.abatch(questions, return_exceptions=True),
    )

    failure_count = 0
    llm_answers: list[LLMAnswerOutput | BaseException] = []
    for question, response in zip(questions, responses, strict=True):
        if isinstance(response, BaseException):
            failure_count += 1
            llm_answers.append(response)
            continue

        # Dumb models sometimes don't return anything.
        if response is None:
            failure_count += 1
            llm_answers.append(ValueError('LLM returned None'))
            continue

        llm_answers.append(
            LLMAnswerOutput(
                number=response.number,
                unit=question['answer_unit'],
            ),
        )

    # Log any failures
    if failure_count > 0:
        logger.warning(
            f'{failure_count}/{len(responses)} LLM answer requests failed',
        )

    logger.info(
        f'Answered {len(responses) - failure_count}/{len(questions)} questions',
    )
    return llm_answers
