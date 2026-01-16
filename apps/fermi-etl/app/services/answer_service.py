"""Service layer for answer generation operations."""

import logging
from collections.abc import Sequence

from fermi_core.op.answer_serp import aget_questions_answers_serp
from fermi_db import DatabaseClient
from fermi_db.models import FermiAnswer
from fermi_db.session import session_context
from pydantic import BaseModel

logger = logging.getLogger(__name__)


class AnswerResult(BaseModel):
    """Result of an answer generation operation."""

    questions_requested: int
    questions_answered: int
    questions_failed: int
    success_rate: float


async def answer_questions(
    question_ids: list[int],
    location_model: str = 'gpt-5-mini',
    extraction_model: str = 'gpt-5-mini',
    model_provider: str = 'openai',
    confidence_threshold: float = 0.8,
) -> AnswerResult:
    """Answer questions and store successful results.

    Args:
        question_ids: List of question IDs to answer
        location_model: Model for location selection
        extraction_model: Model for answer extraction
        model_provider: Model provider
        confidence_threshold: Minimum confidence threshold

    Returns:
        AnswerResult with statistics

    """
    logger.info(f'Starting answer generation for {len(question_ids)} question IDs...')

    # Get database session
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Step 1: Fetch questions by IDs
        logger.info('Fetching questions...')
        questions = await db_client.questions.get_questions_light_by_ids(question_ids)

        if not questions:
            logger.warning('No questions found for provided IDs')
            return AnswerResult(
                questions_requested=len(question_ids),
                questions_answered=0,
                questions_failed=0,
                success_rate=0.0,
            )

        logger.info(f'Found {len(questions)} questions to answer')

        # Step 2: Call SERP API to get answers
        logger.info('Calling SERP API to generate answers...')
        question_texts = [q.text for q in questions]
        answers_or_errors = await aget_questions_answers_serp(
            questions=question_texts,
            location_model=location_model,
            extraction_model=extraction_model,
            model_provider=model_provider,
            confidence_threshold=confidence_threshold,
            temperature=0.0,
            # service_tier='flex',  # TODO: Consider adding answer kwargs input
        )

        # Step 3: Process all answers (successful and failed)
        all_answers: list[FermiAnswer] = []
        successful_count = 0
        failed_count = 0

        for question, result in zip(questions, answers_or_errors, strict=True):
            if isinstance(result, BaseException):
                logger.warning(
                    f'Failed to answer question {question.id}: '
                    f'{type(result).__name__}: {result}',
                )
                # Create a failed answer record
                failed_answer = FermiAnswer(
                    question_id=question.id,  # type: ignore
                    number=0.0,  # Set to 0 for failed attempts as per requirements
                    snippet=str(result)[:500],
                    used_ai_overview=False,
                    success=False,
                    serp_metadata={},
                )
                all_answers.append(failed_answer)
                failed_count += 1
            else:
                # Create successful FermiAnswer record
                answer = FermiAnswer(
                    question_id=question.id,  # type: ignore
                    number=result.number,
                    unit=result.unit,
                    snippet=result.snippet,
                    used_ai_overview=result.used_ai_overview,
                    success=True,
                    serp_metadata=result.metadata,
                )
                all_answers.append(answer)
                successful_count += 1

        # Step 4: Bulk insert/update all answers (successful and failed)
        if all_answers:
            logger.info(
                f'Saving {len(all_answers)} answers ({successful_count} successful, '
                f'{failed_count} failed)...',
            )
            answer_ids = await db_client.fermi_answers.bulk_insert_answers(
                all_answers,
            )
            logger.info(f'Successfully saved {len(answer_ids)} answer records')

        success_rate = successful_count / len(question_ids) if question_ids else 0.0

        logger.info(
            f'Answer generation complete: {successful_count} succeeded, '
            f'{failed_count} failed (success rate: {success_rate:.2%})',
        )

        return AnswerResult(
            questions_requested=len(question_ids),
            questions_answered=successful_count,
            questions_failed=failed_count,
            success_rate=success_rate,
        )


async def answer_unanswered_questions(
    num_questions: int = 50,
    location_model: str = 'gpt-5-mini',
    extraction_model: str = 'gpt-5-mini',
    model_provider: str = 'openai',
    confidence_threshold: float = 0.8,
) -> AnswerResult:
    """Fetch and answer the latest N unanswered questions.

    Args:
        num_questions: Number of unanswered questions to answer
        location_model: Model for location selection
        extraction_model: Model for answer extraction
        model_provider: Model provider
        confidence_threshold: Minimum confidence threshold

    Returns:
        AnswerResult with statistics

    """
    logger.info(f'Fetching and answering {num_questions} unanswered questions...')

    # Get database session and fetch unanswered question IDs
    unanswered_ids: Sequence[int] = []
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Fetch unanswered question IDs
        logger.info(f'Fetching latest {num_questions} unanswered questions...')

        # Use efficient LEFT JOIN query to get unanswered questions in one query
        unanswered_ids = await db_client.fermi_answers.get_latest_unanswered_questions(
            limit=num_questions,
        )

        if not unanswered_ids:
            logger.info('No unanswered questions found')
            return AnswerResult(
                questions_requested=0,
                questions_answered=0,
                questions_failed=0,
                success_rate=1.0,
            )

    logger.info(f'Found {len(unanswered_ids)} unanswered questions')

    # Call answer_questions (which creates its own session)
    return await answer_questions(
        list[int](unanswered_ids),
        location_model=location_model,
        extraction_model=extraction_model,
        model_provider=model_provider,
        confidence_threshold=confidence_threshold,
    )
