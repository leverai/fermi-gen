"""LLM answering service for getting LLM responses to Fermi questions."""

import logging
import random
from typing import Any, Literal

from fermi_core.op import allm_answer_batch
from fermi_core.schemas.llm_answer import LLMAnswerInput
from fermi_db.dal import DatabaseClient
from fermi_db.models import LLMAnswer
from fermi_db.session import session_context
from pydantic import BaseModel

from app.log_context import Stage

logger = logging.getLogger(__name__)


class LLMAnswerResult(BaseModel):
    """Result of an LLM answering operation."""

    model: str
    questions_answered: int
    questions_skipped: int
    details: dict[str, Any]


async def answer_gpt(
    model: Literal['gpt-5.1', 'gpt-5-mini', 'gpt-5-nano'],
    limit: int,
) -> LLMAnswerResult:
    """Answer questions using the specified GPT model.

    Finds questions with successful SerpAPI answers that haven't been
    answered by this GPT model yet, and generates GPT answers for them.

    Args:
        model: GPT model name - one of 'gpt-5.1', 'gpt-5-mini', 'gpt-5-nano'
        model_provider: Model provider
        limit: Maximum number of questions to answer

    Returns:
        LLMAnswerResult with statistics

    """
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Get questions needing LLM answer for this model
        questions_data = await db_client.llm_answers.get_questions_needing_gpt_answer(
            model=model,
            limit=limit,
        )

        if not questions_data:
            logger.info(
                f'No questions need {model} LLM answering',
                extra={'json_fields': {'stage': Stage.GPT_ANSWER, 'model': model}},
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
                    'stage': Stage.GPT_ANSWER,
                    'model': model,
                    'batch_size': len(questions_data),
                },
            },
        )

        # Build LLM inputs
        llm_inputs: list[LLMAnswerInput] = []
        question_ids: list[int] = []
        for question in questions_data:
            llm_inputs.append(
                LLMAnswerInput(
                    question=question['question_text'],
                    answer_unit=question['answer_unit'],
                ),
            )
            question_ids.append(question['question_id'])

        # Batch LLM answering
        results = await allm_answer_batch(
            questions=llm_inputs,
            model=model,
            model_provider='openai',
            temperature=1,
            # service_tier='flex',
        )

        # Process results and prepare database entries
        llm_answers: list[LLMAnswer] = []
        skipped = 0

        for question_id, result in zip(
            question_ids,
            results,
            strict=True,
        ):
            if isinstance(result, BaseException):
                logger.error(
                    f'Failed to LLM answer question {question_id}: {result}',
                    extra={
                        'json_fields': {
                            'stage': Stage.GPT_ANSWER,
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
                            'stage': Stage.GPT_ANSWER,
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
                        'stage': Stage.GPT_ANSWER,
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


async def answer_gemini_flash(
    limit: int,
    model: str = 'gemini-2.5-flash-lite',
    model_provider: str = 'google-vertexai',
    temperature: float = 0.2,
) -> LLMAnswerResult:
    """Answer questions with 5 Gemini Flash instances (batched).

    Generates 5 answers per question using a single batched API call for
    maximum throughput. Successfully generated answers are stored individually.
    Failed answers can be retried by running this function again.

    Uses google-vertexai provider which works with ADC on Cloud Run.

    Args:
        limit: Maximum number of questions to process
        model: Gemini model name (default: gemini-2.5-flash-lite)
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
                    'json_fields': {'stage': Stage.GPT_ANSWER, 'model': 'gemini-flash'},
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
                    'stage': Stage.GEMINI_FLASH_ANSWER,
                    'model': 'gemini-flash',
                    'batch_size': len(questions_data),
                },
            },
        )

        # Build flattened batch: 5 requests per question
        llm_inputs: list[LLMAnswerInput] = []
        request_metadata: list[tuple[int, str]] = []  # (question_id, model_name)

        for question in questions_data:
            for model_idx in range(1, 6):
                llm_inputs.append(
                    LLMAnswerInput(
                        question=question['question_text'],
                        answer_unit=question['answer_unit'],
                    ),
                )
                request_metadata.append(
                    (
                        question['question_id'],
                        f'gemini-flash-{model_idx}',
                    ),
                )

        # Single batched API call for all requests
        results = await allm_answer_batch(
            questions=llm_inputs,
            model=model,
            model_provider=model_provider,
            temperature=temperature,
            top_p=0.99,
            top_k=40,
        )

        # Process results and prepare database entries
        llm_answers: list[LLMAnswer] = []
        questions_with_answers: set[int] = set()
        failed_count = 0

        for (question_id, column_name), result in zip(
            request_metadata,
            results,
            strict=True,
        ):
            if isinstance(result, BaseException):
                logger.warning(
                    f'Gemini Flash failed for Q{question_id} model {column_name}: '
                    f'{result}',
                    extra={
                        'json_fields': {
                            'stage': Stage.GPT_ANSWER,
                            'model': column_name,
                            'question_id': question_id,
                        },
                    },
                )
                failed_count += 1
                continue

            # Handle None results (structured output parsing failed)
            if result is None:
                logger.warning(
                    f'Gemini Flash returned None for Q{question_id} '
                    f'model {column_name} (structured output parsing failed)',
                    extra={
                        'json_fields': {
                            'stage': Stage.GPT_ANSWER,
                            'model': column_name,
                            'question_id': question_id,
                        },
                    },
                )
                failed_count += 1
                continue

            # Success! Scale number by random amount
            scaled_number = result.number * random.uniform(0.4, 2.1)

            llm_answers.append(
                LLMAnswer(
                    question_id=question_id,
                    model=column_name,
                    number=scaled_number,
                    unit=result.unit,
                ),
            )
            questions_with_answers.add(question_id)

        # Batch insert all successful answers
        if llm_answers:
            await db_client.llm_answers.bulk_insert_llm_answers(llm_answers)

        total_answers_stored = len(llm_answers)
        questions_answered = len(questions_with_answers)
        questions_skipped = len(questions_data) - questions_answered

        logger.info(
            f'Gemini Flash complete: {total_answers_stored} answers stored for '
            f'{questions_answered} questions, {failed_count} failed',
            extra={
                'json_fields': {
                    'stage': Stage.GPT_ANSWER,
                    'model': 'gemini-flash',
                    'answers_stored': total_answers_stored,
                    'questions_answered': questions_answered,
                    'failed': failed_count,
                },
            },
        )

        return LLMAnswerResult(
            model='gemini-flash',
            questions_answered=questions_answered,
            questions_skipped=questions_skipped,
            details={
                'total_requested': len(questions_data),
                'total_answers_stored': total_answers_stored,
                'total_answers_failed': failed_count,
                'questions_with_at_least_one_answer': questions_answered,
            },
        )
