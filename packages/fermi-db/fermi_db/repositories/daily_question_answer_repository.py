"""Repository for Daily Question Answer operations."""

import datetime

from sqlalchemy import func
from sqlmodel import select

from fermi_db.models import DailyQuestionAnswer
from fermi_db.repositories import BaseRepository


class DailyQuestionAnswerRepository(BaseRepository):
    """Handle database operations for the daily_question_answers table."""

    async def submit_answer(
        self,
        daily_question_id: int,
        user_firebase_uid: str,
        answer_number: float,
        answer_unit: str | None,
        score: float,
        started_at: datetime.datetime,
        submitted_at: datetime.datetime,
    ) -> DailyQuestionAnswer:
        """Submit an answer for a daily question.

        Args:
            daily_question_id: The ID of the daily question.
            user_firebase_uid: The user's Firebase UID.
            answer_number: The numeric answer value.
            answer_unit: The unit of the answer (optional).
            score: The computed score.
            started_at: When the user started the question (UTC).
            submitted_at: When the answer was submitted (UTC).

        Returns:
            The created DailyQuestionAnswer.

        """
        time_taken_s = (submitted_at - started_at).total_seconds()

        answer = DailyQuestionAnswer(
            daily_question_id=daily_question_id,
            user_firebase_uid=user_firebase_uid,
            answer_number=answer_number,
            answer_unit=answer_unit,
            score=score,
            started_at=started_at,
            submitted_at=submitted_at,
            time_taken_s=time_taken_s,
        )
        self.session.add(answer)
        await self.session.flush()
        await self.session.refresh(answer)
        return answer

    async def get_user_answer(
        self,
        daily_question_id: int,
        user_firebase_uid: str,
    ) -> DailyQuestionAnswer | None:
        """Get a user's answer for a daily question.

        Args:
            daily_question_id: The ID of the daily question.
            user_firebase_uid: The user's Firebase UID.

        Returns:
            The DailyQuestionAnswer if found, None otherwise.

        """
        statement = select(DailyQuestionAnswer).where(
            DailyQuestionAnswer.daily_question_id == daily_question_id,
            DailyQuestionAnswer.user_firebase_uid == user_firebase_uid,
        )
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def has_user_answered(
        self,
        daily_question_id: int,
        user_firebase_uid: str,
    ) -> bool:
        """Check if a user has already answered a daily question.

        Args:
            daily_question_id: The ID of the daily question.
            user_firebase_uid: The user's Firebase UID.

        Returns:
            True if the user has already answered, False otherwise.

        """
        answer = await self.get_user_answer(daily_question_id, user_firebase_uid)
        return answer is not None

    async def get_leaderboard(
        self,
        daily_question_id: int,
        limit: int = 100,
    ) -> list[DailyQuestionAnswer]:
        """Get the leaderboard for a daily question.

        Args:
            daily_question_id: The ID of the daily question.
            limit: Maximum number of entries to return.

        Returns:
            List of answers ordered by score (descending).

        """
        statement = (
            select(DailyQuestionAnswer)
            .where(DailyQuestionAnswer.daily_question_id == daily_question_id)
            .order_by(DailyQuestionAnswer.score.desc())  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return list(result.all())

    async def get_user_rank(
        self,
        daily_question_id: int,
        user_firebase_uid: str,
    ) -> int | None:
        """Get a user's rank for a daily question.

        Rank is computed as 1 + count of users with higher scores.

        Args:
            daily_question_id: The ID of the daily question.
            user_firebase_uid: The user's Firebase UID.

        Returns:
            The user's rank (1-indexed), or None if user hasn't answered.

        """
        # First get the user's score
        user_answer = await self.get_user_answer(daily_question_id, user_firebase_uid)
        if not user_answer:
            return None

        # Count how many users have a higher score
        statement = select(func.count(DailyQuestionAnswer.id)).where(
            DailyQuestionAnswer.daily_question_id == daily_question_id,
            DailyQuestionAnswer.score > user_answer.score,
        )
        result = await self.session.exec(statement)
        higher_count = result.one() or 0

        return higher_count + 1

    async def count_participants(self, daily_question_id: int) -> int:
        """Count the total number of participants for a daily question.

        Args:
            daily_question_id: The ID of the daily question.

        Returns:
            The total number of participants.

        """
        statement = select(func.count(DailyQuestionAnswer.id)).where(
            DailyQuestionAnswer.daily_question_id == daily_question_id,
        )
        result = await self.session.exec(statement)
        return result.one() or 0

    async def compute_and_update_ranks(self, daily_question_id: int) -> int:
        """Compute and update ranks for all answers after window closes.

        Ranks are assigned based on score (highest score = rank 1).
        Ties are handled by assigning the same rank.

        Args:
            daily_question_id: The ID of the daily question.

        Returns:
            The number of answers updated.

        """
        # Get all answers ordered by score
        statement = (
            select(DailyQuestionAnswer)
            .where(DailyQuestionAnswer.daily_question_id == daily_question_id)
            .order_by(DailyQuestionAnswer.score.desc())  # type: ignore
        )
        result = await self.session.exec(statement)
        answers = list(result.all())

        if not answers:
            return 0

        # Assign ranks (handle ties)
        current_rank = 1
        prev_score: float | None = None

        for i, answer in enumerate(answers):
            if prev_score is not None and answer.score < prev_score:
                current_rank = i + 1
            answer.rank = current_rank
            prev_score = answer.score
            self.session.add(answer)

        await self.session.flush()
        return len(answers)
