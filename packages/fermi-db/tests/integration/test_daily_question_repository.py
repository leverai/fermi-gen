"""Behavioral tests for the daily-question archive queries."""

import datetime
import uuid

import pytest_asyncio
from fermi_db.models import DailyQuestion, DailyQuestionAnswer, Fermi
from fermi_db.repositories.daily_question_repository import DailyQuestionRepository
from fermi_db.schemas import DailyQuestionStatus, QuestionDifficulty, QuestionStatus
from sqlmodel.ext.asyncio.session import AsyncSession


def _fermi(index: int) -> Fermi:
    now = datetime.datetime(2026, 1, 1)  # noqa: DTZ001 - DB stores naive UTC
    return Fermi(
        uid=uuid.uuid4(),
        question_id=index,
        text=f'Daily question {index}',
        question_source={},
        answer_id=index,
        number=float(index),
        unit=None,
        snippet='snippet',
        used_ai_overview=False,
        difficulty=QuestionDifficulty.MEDIUM,
        category=None,
        embedding=None,
        random_sort_key=index,
        created_at=now,
        updated_at=now,
        status=QuestionStatus.APPROVED,
        is_daily_question=True,
        gpt_5_1_number=float(index),
        gpt_5_1_unit=None,
        gpt_5_mini_number=float(index),
        gpt_5_mini_unit=None,
        gpt_5_nano_number=float(index),
        gpt_5_nano_unit=None,
        gemini_flash_1_number=float(index),
        gemini_flash_1_unit=None,
        gemini_flash_2_number=float(index),
        gemini_flash_2_unit=None,
        gemini_flash_3_number=float(index),
        gemini_flash_3_unit=None,
        gemini_flash_4_number=float(index),
        gemini_flash_4_unit=None,
        gemini_flash_5_number=float(index),
        gemini_flash_5_unit=None,
    )


@pytest_asyncio.fixture
async def repo(session: AsyncSession) -> DailyQuestionRepository:
    """Return a daily-question repository bound to the clean test session."""
    return DailyQuestionRepository(session)


async def test_week_archive_returns_latest_eight_questions_across_date_gaps(
    session: AsyncSession,
    repo: DailyQuestionRepository,
) -> None:
    """A long publishing pause must not empty the main-screen carousel."""
    question_dates = [
        datetime.date(2026, 1, 3),
        datetime.date(2026, 2, 14),
        datetime.date(2026, 3, 20),
        datetime.date(2026, 4, 4),
        datetime.date(2026, 5, 9),
        datetime.date(2026, 6, 12),
        datetime.date(2026, 7, 18),
        datetime.date(2026, 8, 22),
        datetime.date(2026, 9, 26),
        datetime.date(2026, 10, 17),
    ]
    questions = [_fermi(index) for index in range(1, len(question_dates) + 1)]
    session.add_all(questions)
    await session.flush()

    window_start = datetime.datetime(2026, 1, 1)  # noqa: DTZ001
    daily_questions = [
        DailyQuestion(
            question_date=question_date,
            question_uid=question.uid,
            status=DailyQuestionStatus.CLOSED,
            window_start=window_start,
            window_end=window_start + datetime.timedelta(hours=14),
        )
        for question_date, question in zip(question_dates, questions, strict=True)
    ]
    session.add_all(daily_questions)
    await session.flush()

    participated = daily_questions[3]  # April 4 remains inside the latest eight.
    assert participated.id is not None
    session.add(
        DailyQuestionAnswer(
            daily_question_id=participated.id,
            user_firebase_uid='sparse-history-user',
            answer_number=4.0,
            answer_unit=None,
            score=900.0,
            started_at=window_start,
            submitted_at=window_start + datetime.timedelta(seconds=10),
            time_taken_s=10.0,
        ),
    )
    await session.commit()

    items = await repo.get_lite_archive_for_week(
        'sparse-history-user',
        today=datetime.date(2026, 12, 31),
    )

    assert items == {
        '2026-10-17': False,
        '2026-09-26': False,
        '2026-08-22': False,
        '2026-07-18': False,
        '2026-06-12': False,
        '2026-05-09': False,
        '2026-04-04': True,
        '2026-03-20': False,
    }
