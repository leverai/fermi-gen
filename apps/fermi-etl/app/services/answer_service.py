"""Service layer for answer generation operations."""

import logging

from fermi_core.op.answer_serp import aget_questions_answers_serp
from fermi_db import DatabaseClient
from fermi_db.models import FermiAnswer
from fermi_db.session import session_context
from pydantic import BaseModel

from app.config import ETLConfig

logger = logging.getLogger(__name__)


class AnswerResult(BaseModel):
    """Result of an answer generation operation."""

    questions_requested: int
    questions_answered: int
    questions_failed: int
    success_rate: float


async def answer_questions(
    question_ids: list[int],
    config: ETLConfig | None = None,
) -> AnswerResult:
    """Answer questions and store successful results.

    Args:
        question_ids: List of question IDs to answer
        config: ETL configuration (if None, load from env)

    Returns:
        AnswerResult with statistics

    """
    if config is None:
        from app.config import get_config

        config = get_config()

    logger.info(f'Starting answer generation for {len(question_ids)} question IDs...')

    # Get database session
    async with session_context() as session:
        db_client = DatabaseClient(session)

        # Step 1: Fetch questions by IDs
        logger.info('Fetching questions...')
        questions = await db_client.questions.get_questions_by_ids(question_ids)

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
            location_model=config.location_model,
            extraction_model=config.extraction_model,
            model_provider=config.model_provider,
            confidence_threshold=config.confidence_threshold,
            temperature=0.0,
            # service_tier='flex',
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
                    snippet=(
                        f'Failed to answer: {type(result).__name__}: '
                        f'{str(result)[:500]}'
                    ),
                    used_ai_overview=False,
                    success=False,
                    serp_metadata={
                        'error': type(result).__name__,
                        'message': str(result)[:500],
                    },
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

    # Should never reach here due to async generator
    raise RuntimeError('Failed to get database session')


async def answer_unanswered_questions(
    num_questions: int = 50,
    config: ETLConfig | None = None,
) -> AnswerResult:
    """Fetch and answer the latest N unanswered questions.

    Args:
        num_questions: Number of unanswered questions to answer
        config: ETL configuration (if None, load from env)

    Returns:
        AnswerResult with statistics

    """
    if config is None:
        from app.config import get_config

        config = get_config()

    logger.info(f'Fetching and answering {num_questions} unanswered questions...')

    # Get database session and fetch unanswered question IDs
    unanswered_ids: list[int] = []
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
                success_rate=0.0,
            )

    logger.info(f'Found {len(unanswered_ids)} unanswered questions')

    # Call answer_questions (which creates its own session)
    return await answer_questions(unanswered_ids, config)
