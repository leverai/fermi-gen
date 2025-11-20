"""Function to generate a batch of Fermi questions."""

import logging
from typing import Any, cast

from fermi_core.prompts import ASK_PROMPT
from fermi_core.schemas.ask import AskQuestionBatch, AskState
from fermi_core.utils import create_generic_chain

logger = logging.getLogger(__name__)


async def aask(
    seed: str,
    num_questions: int = 10,
    *,
    model: str = 'gpt-4o-mini',
    model_provider: str = 'openai',
    **model_kwargs: Any,
) -> AskQuestionBatch:
    """Create a batch of Fermi questions asynchronously."""
    # Create and invoke the chain
    chain = create_generic_chain(
        model=model,
        model_provider=model_provider,
        prompt=ASK_PROMPT,
        output_schema=AskQuestionBatch,
        input_schema=AskState,
        **model_kwargs,
    )
    logger.info(
        f"Generating {num_questions} questions for seed: '{seed}' "
        f'using model {model} with kwargs {model_kwargs}...',
    )
    ask_state = AskState(
        num_questions=num_questions,
        seed=seed,
    )
    response = await chain.ainvoke(ask_state)
    return response


async def aask_batch(
    seeds: list[str],
    num_questions: int = 10,
    *,
    model: str = 'gpt-4o-mini',
    model_provider: str = 'openai',
    **model_kwargs: Any,
) -> list[AskQuestionBatch | BaseException]:
    """Create batches of Fermi questions for multiple seeds concurrently.

    Uses LangChain's abatch to send a single API call for multiple inputs,
    significantly improving throughput.

    Returns exceptions in the result list (similar to asyncio.gather with
    return_exceptions=True) to maintain 1:1 correspondence between inputs
    and outputs.

    Args:
        seeds: List of seeds to generate questions for
        num_questions: Number of questions per seed
        model: LLM model to use
        model_provider: Model provider (e.g., 'openai')
        **model_kwargs: Additional model configuration

    Returns:
        List of AskQuestionBatch or BaseException, one for each seed in order

    """
    if not seeds:
        return []

    # Create chain once for all seeds
    chain = create_generic_chain(
        model=model,
        model_provider=model_provider,
        prompt=ASK_PROMPT,
        output_schema=AskQuestionBatch,
        input_schema=AskState,
        **model_kwargs,
    )

    logger.info(
        f'Generating {num_questions} questions for {len(seeds)} seeds '
        f'using model {model} (batch mode)...',
    )

    # Prepare input states for all seeds
    ask_states = [AskState(num_questions=num_questions, seed=seed) for seed in seeds]

    # Batch invoke - sends all requests concurrently
    # return_exceptions=True maintains 1:1 correspondence with inputs
    responses = cast(
        list[AskQuestionBatch | BaseException],
        await chain.abatch(ask_states, return_exceptions=True),
    )

    # Log any failures
    failure_count = sum(1 for r in responses if isinstance(r, BaseException))
    if failure_count > 0:
        logger.warning(f'{failure_count}/{len(responses)} seed requests failed')

    logger.info(
        f'Generated questions for {len(responses) - failure_count}/{len(seeds)} seeds',
    )
    return responses
