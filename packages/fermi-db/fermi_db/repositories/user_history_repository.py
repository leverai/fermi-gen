"""Repository for user history-related database operations."""

from collections.abc import Iterable
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert
from sqlmodel import select

from fermi_db.models import UserQuestionHistory
from fermi_db.repositories import BaseRepository


class UserHistoryRepository(BaseRepository):
    """Handles database operations related to user history."""

    async def add_questions_to_users_history(
        self,
        user_ids: Iterable[str],
        question_uids: Iterable[UUID],
    ) -> None:
        """Add multiple questions to multiple users' seen history."""
        if not user_ids or not question_uids:
            return

        insert_stmt = insert(UserQuestionHistory).values(
            [
                {
                    'user_id': uid,
                    'question_uid': qid,
                    'seen_at': func.now(),
                }
                for uid in user_ids
                for qid in question_uids
            ],
        )

        await self.session.execute(insert_stmt)  # type: ignore
        await self.session.commit()

    async def has_user_seen_question(self, user_id: str, question_uid: UUID) -> bool:
        """Check if a user has seen a question."""
        statement = select(UserQuestionHistory).where(
            UserQuestionHistory.user_id == user_id,
            UserQuestionHistory.question_uid == question_uid,
        )
        result = await self.session.exec(statement)
        return result.one_or_none() is not None
