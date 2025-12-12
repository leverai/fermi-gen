"""LLM answering service for getting LLM responses to Fermi questions."""

import logging
from typing import Any

from fermi_core.op import allm_answer_batch
from fermi_core.schemas.llm_answer import LLMAnswerInput
from fermi_core.units import get_units_ladder
from fermi_db.dal import DatabaseClient
from fermi_db.models import LLMAnswer
from fermi_db.session import session_context
from pydantic import BaseModel

from app.config import ETLConfig

logger = logging.getLogger(__name__)


class LLMAnswerResult(BaseModel):
    """Result of an LLM answering operation."""

    model: str
    questions_answered: int
    questions_skipped: int
    details: dict[str, Any]


async def llm_answer_questions(
    model: str,
    limit: int,
    config: ETLConfig,
) -> LLMAnswerResult:
    """Answer questions using the specified LLM model.

    Finds questions with successful SerpAPI answers that haven't been
    answered by this model yet, and generates LLM answers for them.

    Args:
        model: LLM model name (e.g., 'gpt-5.1', 'gpt-5-mini', 'gpt-5-nano')
        limit: Maximum number of questions to answer
        config: Application configuration

    Returns:
        LLMAnswerResult with statistics

    """
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Get questions needing LLM answer for this model
        questions_data = await db_client.llm_answers.get_questions_needing_llm_answer(
            model=model,
            limit=limit,
        )

        if not questions_data:
            logger.info(f'No questions need {model} LLM answering')
            return LLMAnswerResult(
                model=model,
                questions_answered=0,
                questions_skipped=0,
                details={'message': f'No questions need {model} answering'},
            )

        logger.info(f'LLM answering {len(questions_data)} questions with {model}')

        # Build LLM inputs with units_set for dimensional questions
        llm_inputs: list[LLMAnswerInput] = []
        question_ids: list[int] = []

        units_sets: list[list[str] | None] = []
        for question_id, question_text, answer_unit in questions_data:
            # Get units ladder for dimensional questions
            units_set: list[str] | None = None
            if answer_unit:
                try:
                    units_ladder = get_units_ladder(answer_unit)
                    units_set = [u['id'] for u in units_ladder]
                except ValueError:
                    logger.warning(
                        f'Unknown unit {answer_unit} for question {question_id}',
                    )

            llm_inputs.append(
                LLMAnswerInput(question=question_text, units_set=units_set),
            )
            question_ids.append(question_id)
            units_sets.append(units_set)

        # Batch LLM answering
        results = await allm_answer_batch(
            questions=llm_inputs,
            model=model,
            model_provider=config.llm_answer_model_provider,
            temperature=0.5,
            # service_tier='flex',
        )

        # Process results and prepare database entries
        llm_answers: list[LLMAnswer] = []
        skipped = 0

        for question_id, result, units_set in zip(
            question_ids,
            results,
            units_sets,
            strict=True,
        ):
            if isinstance(result, BaseException):
                logger.error(f'Failed to LLM answer question {question_id}: {result}')
                skipped += 1
                continue

            # Validate the the agent did choose a valid unit from the set.
            if units_set and result.unit not in units_set:
                logger.error(
                    f'LLM answer unit {result.unit} does not match expected units '
                    f'{units_set} for question {question_id}',
                )
                skipped += 1
                continue

            llm_answers.append(
                LLMAnswer(
                    question_id=question_id,
                    model=model,
                    number=result.number,
                    unit=result.unit,
                ),
            )

        # Batch insert to database
        if llm_answers:
            await db_client.llm_answers.bulk_insert_llm_answers(llm_answers)
            logger.info(
                f'Successfully stored {len(llm_answers)} {model} LLM answers',
            )

        return LLMAnswerResult(
            model=model,
            questions_answered=len(llm_answers),
            questions_skipped=skipped,
            details={
                'total_requested': len(questions_data),
                'successful': len(llm_answers),
                'failed': skipped,
            },
        )
