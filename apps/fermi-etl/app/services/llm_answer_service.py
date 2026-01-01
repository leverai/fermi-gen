"""LLM answering service for getting LLM responses to Fermi questions."""

import logging
import random
import traceback
from typing import Any

from fermi_core.op import allm_answer_batch
from fermi_core.schemas.llm_answer import LLMAnswerInput
from fermi_core.units import get_units_ladder
from fermi_db.dal import DatabaseClient
from fermi_db.models import LLMAnswer
from fermi_db.session import session_context
from pydantic import BaseModel

from app.config import ETLConfig
from app.log_context import Stage

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
            logger.info(
                f'No questions need {model} LLM answering',
                extra={'json_fields': {'stage': Stage.LLM_ANSWER, 'model': model}},
            )
            return LLMAnswerResult(
                model=model,
                questions_answered=0,
                questions_skipped=0,
                details={'message': f'No questions need {model} answering'},
            )

        logger.info(
            f'LLM answering {len(questions_data)} questions with {model}',
            extra={
                'json_fields': {
                    'stage': Stage.LLM_ANSWER,
                    'model': model,
                    'batch_size': len(questions_data),
                },
            },
        )

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
                        extra={
                            'json_fields': {
                                'stage': Stage.LLM_ANSWER,
                                'model': model,
                                'question_id': question_id,
                                'unit': answer_unit,
                            },
                        },
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
            temperature=1,
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
                logger.error(
                    f'Failed to LLM answer question {question_id}: {result}',
                    extra={
                        'json_fields': {
                            'stage': Stage.LLM_ANSWER,
                            'model': model,
                            'question_id': question_id,
                        },
                    },
                )
                skipped += 1
                continue

            # Handle None results (structured output parsing failed silently)
            if result is None:
                logger.error(
                    f'LLM returned None for question {question_id} '
                    '(structured output parsing failed)',
                    extra={
                        'json_fields': {
                            'stage': Stage.LLM_ANSWER,
                            'model': model,
                            'question_id': question_id,
                        },
                    },
                )
                skipped += 1
                continue

            # Validate the the agent did choose a valid unit from the set.
            if units_set and result.unit not in units_set:
                logger.error(
                    f'LLM answer unit {result.unit} does not match expected units '
                    f'{units_set} for question {question_id}',
                    extra={
                        'json_fields': {
                            'stage': Stage.LLM_ANSWER,
                            'model': model,
                            'question_id': question_id,
                        },
                    },
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
                extra={
                    'json_fields': {
                        'stage': Stage.LLM_ANSWER,
                        'model': model,
                        'stored': len(llm_answers),
                        'skipped': skipped,
                    },
                },
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


async def gemini_flash_answer_questions(
    limit: int,
    model_name: str = 'gemini-2.5-flash-lite',
    model_provider: str = 'google-vertexai',
    temperature: float = 0.2,
) -> LLMAnswerResult:
    """Answer questions with 5 Gemini Flash instances (atomic upload).

    For each question:
    1. Generate 5 answers using Gemini Flash
    2. If ALL 5 succeed → store all 5 atomically
    3. If ANY fail → skip the question entirely

    Uses google-vertexai provider which works with ADC on Cloud Run.

    Args:
        limit: Maximum number of questions to process
        model_name: Gemini model name (default: gemini-2.5-flash-lite)
        model_provider: Model provider (default: google-vertexai)
        temperature: Temperature for generation (default: 0.2, max: 0.2)

    Returns:
        LLMAnswerResult with statistics

    """
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Get questions needing all Gemini answers
        questions_data = (
            await db_client.llm_answers.get_questions_needing_all_gemini_answers(
                limit=limit,
            )
        )

        if not questions_data:
            logger.info(
                'No questions need Gemini Flash answering',
                extra={
                    'json_fields': {'stage': Stage.LLM_ANSWER, 'model': 'gemini-flash'},
                },
            )
            return LLMAnswerResult(
                model='gemini-flash',
                questions_answered=0,
                questions_skipped=0,
                details={'message': 'No questions need Gemini Flash answering'},
            )

        logger.info(
            f'Gemini Flash answering {len(questions_data)} questions (5 answers each)',
            extra={
                'json_fields': {
                    'stage': Stage.LLM_ANSWER,
                    'model': 'gemini-flash',
                    'batch_size': len(questions_data),
                },
            },
        )

        # Build LLM inputs
        llm_inputs: list[LLMAnswerInput] = []
        question_ids: list[int] = []
        units_sets: list[list[str] | None] = []

        for question_id, question_text, answer_unit in questions_data:
            units_set: list[str] | None = None
            if answer_unit:
                try:
                    units_ladder = get_units_ladder(answer_unit)
                    units_set = [u['id'] for u in units_ladder]
                except ValueError:
                    logger.warning(
                        f'Unknown unit {answer_unit} for question {question_id}',
                        extra={
                            'json_fields': {
                                'stage': Stage.LLM_ANSWER,
                                'model': 'gemini-flash',
                                'question_id': question_id,
                                'unit': answer_unit,
                            },
                        },
                    )

            llm_inputs.append(
                LLMAnswerInput(question=question_text, units_set=units_set),
            )
            question_ids.append(question_id)
            units_sets.append(units_set)

        # Generate 5 answers per question, atomically
        total_stored = 0
        total_skipped = 0

        for question_id, llm_input, units_set in zip(
            question_ids,
            llm_inputs,
            units_sets,
            strict=True,
        ):
            # Generate 5 answers for this question
            answers_for_question: list[LLMAnswer] = []
            all_succeeded = True

            for model_idx in range(1, 6):
                column_name = f'gemini-flash-{model_idx}'
                max_attempts = 3
                attempt = 0
                model_succeeded = False

                while attempt < max_attempts and not model_succeeded:
                    attempt += 1
                    try:
                        results = await allm_answer_batch(
                            questions=[llm_input],
                            model=model_name,
                            model_provider=model_provider,
                            temperature=temperature,
                            top_p=0.99,
                            top_k=40,
                        )
                        result = results[0]

                        if isinstance(result, BaseException):
                            logger.warning(
                                f'Gemini Flash failed for Q{question_id} '
                                f'model {model_idx} attempt {attempt}/{max_attempts}: '
                                f'{result}',
                                extra={
                                    'json_fields': {
                                        'stage': Stage.LLM_ANSWER,
                                        'model': column_name,
                                        'question_id': question_id,
                                        'attempt': attempt,
                                    },
                                },
                            )
                            continue  # Retry

                        # Handle None results (structured output parsing failed)
                        if result is None:
                            logger.warning(
                                f'Gemini Flash returned None for Q{question_id} '
                                f'model {model_idx} attempt {attempt}/{max_attempts} '
                                '(structured output parsing failed)',
                                extra={
                                    'json_fields': {
                                        'stage': Stage.LLM_ANSWER,
                                        'model': column_name,
                                        'question_id': question_id,
                                        'attempt': attempt,
                                    },
                                },
                            )
                            continue  # Retry

                        if units_set and result.unit not in units_set:
                            logger.warning(
                                f'Gemini unit {result.unit} not in {units_set} '
                                f'for Q{question_id} attempt {attempt}/{max_attempts}',
                                extra={
                                    'json_fields': {
                                        'stage': Stage.LLM_ANSWER,
                                        'model': column_name,
                                        'question_id': question_id,
                                        'attempt': attempt,
                                    },
                                },
                            )
                            continue  # Retry

                        # Validate unit
                        if not units_set and result.unit:
                            logger.warning(
                                f'Gemini unit {result.unit} received with no units '
                                f'set for Q{question_id} attempt '
                                f'{attempt}/{max_attempts}',
                                extra={
                                    'json_fields': {
                                        'stage': Stage.LLM_ANSWER,
                                        'model': column_name,
                                        'question_id': question_id,
                                        'attempt': attempt,
                                    },
                                },
                            )
                            continue  # Retry

                        # Success! Scale number by random amount
                        result.number *= random.uniform(0.4, 2.1)

                        answers_for_question.append(
                            LLMAnswer(
                                question_id=question_id,
                                model=column_name,
                                number=result.number,
                                unit=result.unit,
                            ),
                        )
                        model_succeeded = True

                    except Exception as e:
                        logger.warning(
                            f'Exception in Gemini Flash for Q{question_id} '
                            f'model {model_idx} attempt {attempt}/{max_attempts}: '
                            f'{e}\n{traceback.format_exc()}',
                            extra={
                                'json_fields': {
                                    'stage': Stage.LLM_ANSWER,
                                    'model': column_name,
                                    'question_id': question_id,
                                    'attempt': attempt,
                                },
                            },
                        )
                        continue  # Retry

                # If all attempts failed for this model, skip the question
                if not model_succeeded:
                    logger.error(
                        f'All {max_attempts} attempts failed for Q{question_id} '
                        f'model {model_idx}',
                        extra={
                            'json_fields': {
                                'stage': Stage.LLM_ANSWER,
                                'model': column_name,
                                'question_id': question_id,
                            },
                        },
                    )
                    all_succeeded = False
                    break

            # Atomic insert: all 5 or none
            if all_succeeded and len(answers_for_question) == 5:
                await db_client.llm_answers.bulk_insert_llm_answers(
                    answers_for_question,
                )
                total_stored += 1
                logger.debug(
                    f'Stored 5 Gemini answers for Q{question_id}',
                    extra={
                        'json_fields': {
                            'stage': Stage.LLM_ANSWER,
                            'model': 'gemini-flash',
                            'question_id': question_id,
                        },
                    },
                )
            else:
                total_skipped += 1

        logger.info(
            f'Gemini Flash complete: {total_stored} questions answered, '
            f'{total_skipped} skipped',
            extra={
                'json_fields': {
                    'stage': Stage.LLM_ANSWER,
                    'model': 'gemini-flash',
                    'stored': total_stored,
                    'skipped': total_skipped,
                },
            },
        )

        return LLMAnswerResult(
            model='gemini-flash',
            questions_answered=total_stored,
            questions_skipped=total_skipped,
            details={
                'total_requested': len(questions_data),
                'questions_fully_answered': total_stored,
                'questions_failed': total_skipped,
                'answers_per_question': 5,
            },
        )
