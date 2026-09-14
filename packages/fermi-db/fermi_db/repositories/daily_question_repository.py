"""Repository for Daily Question table operations."""

import datetime
import logging
import uuid

from sqlalchemy import func
from sqlmodel import select

from fermi_db.models import DailyQuestion, DailyQuestionAnswer, Fermi
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import DailyQuestionStatus, QuestionStatus

logger = logging.getLogger(__name__)


class DailyQuestionRepository(BaseRepository):
    """Handle database operations for the daily_questions table."""

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

    async def schedule_dq_for_date(
        self,
        date: datetime.date,
        window_start: datetime.datetime,
        window_end: datetime.datetime,
    ) -> DailyQuestion:
        """Schedule the daily question for a specific date.
        Adds a new SCHEDULED DQ entry if none exists for that date,
        otherwise, returns the existing entry.

        Args:
            date: The date to look up.
            window_start: The start time of the window.
            window_end: The end time of the window.

        Returns:
            The scheduled DailyQuestion.

        """
        # Ensure date isn't active or closed. Return if scheduled already.
        existing = await self.get_dq_for_date(date)
        if existing:
            if existing.status == DailyQuestionStatus.ACTIVE:
                raise ValueError('An active DQ already exists for that date.')
            if existing.status == DailyQuestionStatus.CLOSED:
                raise ValueError('A closed DQ already exists for that date.')

            if existing.status == DailyQuestionStatus.SCHEDULED:
                logger.warning('A scheduled DQ already exists for date %s.', date)
                return existing

        # Find the next unused dq and schedule it.
        fermi = await self.get_next_unused_fermi_dq()
        if not fermi:
            raise ValueError('No unused DQ questions available.')
        dq = DailyQuestion(
            question_uid=fermi.uid,
            question_date=date,
            status=DailyQuestionStatus.SCHEDULED,
            window_start=window_start,
            window_end=window_end,
        )

        self.session.add(dq)
        await self.session.flush()
        await self.session.refresh(dq)
        return dq

    async def schedule_daily_question(
        self,
        question_uid: uuid.UUID,
        question_date: datetime.date,
        window_start: datetime.datetime,
        window_end: datetime.datetime,
    ) -> DailyQuestion:
        """Schedule a new daily question entry.

        Args:
            question_uid: The fermi.uid of the question to use.
            question_date: The date for this daily question.
            window_start: When the DQ window opens (UTC).
            window_end: When the DQ window closes (UTC).

        Returns:
            The scheduled DailyQuestion.

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

    async def count_active_dqs(self) -> int:
        """Count the number of active daily questions."""
        statement = select(func.count(DailyQuestion.id)).where(
            DailyQuestion.status == DailyQuestionStatus.ACTIVE,
        )
        result = await self.session.exec(statement)
        return result.scalar_one_or_none() or 0

    async def update_dq_status(
        self,
        dq_id: int,
        status: DailyQuestionStatus,
    ) -> bool:
        """Update the status of a daily question.

        Args:
            dq_id: The ID of the daily question.
            status: The new status.

        Returns:
            True if the update was successful, False otherwise.

        """
        statement = select(DailyQuestion).where(DailyQuestion.id == dq_id)
        result = await self.session.exec(statement)
        dq = result.one()
        if not dq:
            return False
        dq.status = status
        self.session.add(dq)
        await self.session.flush()
        return True

    async def get_next_unused_fermi_dq(self) -> Fermi | None:
        """Get the next unused DQ-flagged question.

        Returns the latest-created APPROVED question that:
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
            .order_by(Fermi.created_at.desc())  # type: ignore
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

    async def get_active_dq_date(self) -> datetime.date | None:
        """Get the date of the currently active daily question.

        Returns:
            The date of the active daily question, or None.

        """
        statement = select(DailyQuestion.question_date).where(
            DailyQuestion.status == DailyQuestionStatus.ACTIVE,
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def count_dq_questions_available(self, status: QuestionStatus | None) -> int:
        """Count how many unused DQ questions are available.

        Args:
            status: The status of the DQ questions to count. If None, counts all DQ
                questions.

        Returns:
            The count of available DQ questions.

        """
        used_uids_subquery = select(DailyQuestion.question_uid).subquery()

        statement = select(func.count(Fermi.uid)).where(
            Fermi.is_daily_question == True,  # noqa: E712
            ~Fermi.uid.in_(select(used_uids_subquery)),  # type: ignore
        )
        if status:
            statement = statement.where(Fermi.status == status)
        result = await self.session.exec(statement)
        return result.one() or 0

    async def get_lite_archive_for_week(
        self,
        user_firebase_uid: str,
        today: datetime.date,
    ) -> dict[str, bool]:
        """Get the latest eight DQs up to and including today.

        Returns a dictionary keyed by date (YYYY-MM-DD) with boolean values
        indicating whether the user participated. Selecting question rows rather
        than a calendar range keeps the carousel populated when publishing pauses.

        Args:
            user_firebase_uid: The user's Firebase UID.
            today: Today's DQ date.

        Returns:
            Dictionary of {date_str: user_participated}.

        """
        # Get the latest eight DQs with an optional answer from this user.
        statement = (
            select(
                DailyQuestion.question_date,
                DailyQuestionAnswer.id.label('answer_id'),  # type: ignore
            )
            .select_from(DailyQuestion)
            .outerjoin(
                DailyQuestionAnswer,
                (DailyQuestion.id == DailyQuestionAnswer.daily_question_id)  # type: ignore
                & (DailyQuestionAnswer.user_firebase_uid == user_firebase_uid),  # type: ignore
            )
            .where(
                DailyQuestion.question_date <= today,
            )
            .order_by(DailyQuestion.question_date.desc())  # type: ignore
            .limit(8)
        )

        result = await self.session.exec(statement)
        rows = result.all()

        return {
            row.question_date.strftime('%Y-%m-%d'): row.answer_id is not None
            for row in rows
        }

    async def get_lite_archive_for_month(
        self,
        user_firebase_uid: str,
        year: int,
        month: int,
    ) -> dict[str, bool]:
        """Get lite archive for a specific month.

        Returns a dictionary keyed by date (YYYY-MM-DD) with boolean values
        indicating whether the user participated.

        Args:
            user_firebase_uid: The user's Firebase UID.
            year: The year (e.g., 2024).
            month: The month (1-12).

        Returns:
            Dictionary of {date_str: user_participated}.

        """
        # Calculate month start and end dates
        month_start = datetime.date(year, month, 1)
        if month == 12:
            month_end = datetime.date(year + 1, 1, 1) - datetime.timedelta(days=1)
        else:
            month_end = datetime.date(year, month + 1, 1) - datetime.timedelta(days=1)

        # Get all DQs in range with optional user answer
        statement = (
            select(
                DailyQuestion.question_date,
                DailyQuestionAnswer.id.label('answer_id'),  # type: ignore
            )
            .select_from(DailyQuestion)
            .outerjoin(
                DailyQuestionAnswer,
                (DailyQuestion.id == DailyQuestionAnswer.daily_question_id)  # type: ignore
                & (DailyQuestionAnswer.user_firebase_uid == user_firebase_uid),  # type: ignore
            )
            .where(
                DailyQuestion.question_date >= month_start,
                DailyQuestion.question_date <= month_end,
            )
            .order_by(DailyQuestion.question_date.asc())  # type: ignore
        )

        result = await self.session.exec(statement)
        rows = result.all()

        return {
            row.question_date.strftime('%Y-%m-%d'): row.answer_id is not None
            for row in rows
        }
