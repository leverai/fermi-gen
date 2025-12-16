"""Repository for Daily Question table operations."""

import datetime
import uuid

from sqlalchemy import func
from sqlmodel import select

from fermi_db.models import DailyQuestion, Fermi
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import DailyQuestionStatus, QuestionStatus


class DailyQuestionRepository(BaseRepository):
    """Handle database operations for the daily_questions table."""

    async def get_todays_dq(self, today: datetime.date) -> DailyQuestion | None:
        """Get today's daily question if it exists.

        Args:
            today: The date to check for (should be UTC date).

        Returns:
            The DailyQuestion for today, or None if not found.

        """
        statement = select(DailyQuestion).where(
            DailyQuestion.question_date == today,
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def get_dq_for_date(self, date: datetime.date) -> DailyQuestion | None:
        """Get the daily question for a specific date.

        Args:
            date: The date to look up.

        Returns:
            The DailyQuestion for that date, or None if not found.

        """
        statement = select(DailyQuestion).where(
            DailyQuestion.question_date == date,
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def create_daily_question(
        self,
        question_uid: uuid.UUID,
        question_date: datetime.date,
        window_start: datetime.datetime,
        window_end: datetime.datetime,
    ) -> DailyQuestion:
        """Create a new daily question entry.

        Args:
            question_uid: The fermi.uid of the question to use.
            question_date: The date for this daily question.
            window_start: When the DQ window opens (UTC).
            window_end: When the DQ window closes (UTC).

        Returns:
            The created DailyQuestion.

        """
        dq = DailyQuestion(
            question_uid=question_uid,
            question_date=question_date,
            status=DailyQuestionStatus.SCHEDULED,
            window_start=window_start,
            window_end=window_end,
        )
        self.session.add(dq)
        await self.session.flush()
        await self.session.refresh(dq)
        return dq

    async def update_dq_status(
        self,
        dq_id: int,
        status: DailyQuestionStatus,
    ) -> None:
        """Update the status of a daily question.

        Args:
            dq_id: The ID of the daily question.
            status: The new status.

        """
        statement = select(DailyQuestion).where(DailyQuestion.id == dq_id)
        result = await self.session.exec(statement)
        dq = result.one()
        dq.status = status
        self.session.add(dq)
        await self.session.flush()

    async def get_next_unused_dq_question(self) -> Fermi | None:
        """Get the next unused DQ-flagged question.

        Returns the earliest-created APPROVED question that:
        - Has is_daily_question = True
        - Has never been used in a daily_questions entry

        Returns:
            A Fermi question, or None if no unused DQ questions exist.

        """
        # Subquery: get all question_uids that have been used
        used_uids_subquery = select(DailyQuestion.question_uid).subquery()

        # Main query: find approved DQ questions not in used set
        statement = (
            select(Fermi)
            .where(
                Fermi.status == QuestionStatus.APPROVED,
                Fermi.is_daily_question == True,  # noqa: E712
                ~Fermi.uid.in_(select(used_uids_subquery)),  # type: ignore
            )
            .order_by(Fermi.created_at.asc())  # type: ignore
            .limit(1)
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def get_active_dq(self) -> DailyQuestion | None:
        """Get the currently active daily question.

        Returns:
            The DailyQuestion with ACTIVE status, or None.

        """
        statement = select(DailyQuestion).where(
            DailyQuestion.status == DailyQuestionStatus.ACTIVE,
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def count_dq_questions_available(self) -> int:
        """Count how many unused DQ questions are available.

        Returns:
            The count of available DQ questions.

        """
        used_uids_subquery = select(DailyQuestion.question_uid).subquery()

        statement = select(func.count(Fermi.uid)).where(
            Fermi.status == QuestionStatus.APPROVED,
            Fermi.is_daily_question == True,  # noqa: E712
            ~Fermi.uid.in_(select(used_uids_subquery)),  # type: ignore
        )
        result = await self.session.exec(statement)
        return result.one() or 0
