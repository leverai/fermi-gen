"""Repository for raw question database operations."""

from typing import cast

from sqlalchemy import func
from sqlmodel import select

from fermi_db.models import RawQuestion
from fermi_db.repositories import BaseRepository


class RawQuestionRepository(BaseRepository):
    """Handle database operations for raw (pre-dedup) questions."""

    async def bulk_insert_raw_questions(
        self,
        questions: list[RawQuestion],
    ) -> None:
        """Bulk insert raw questions.

        Args:
            questions: List of RawQuestion instances to insert

        """
        if not questions:
            return

        self.session.add_all(questions)
        await self.session.commit()

    async def get_pending_raw_questions(
        self,
        limit: int = 1000,
    ) -> list[RawQuestion]:
        """Get raw questions with pending dedup status.

        Args:
            limit: Maximum number of questions to fetch

        Returns:
            List of pending RawQuestion instances

        """
        statement = (
            select(RawQuestion)
            .where(RawQuestion.dedup_status == 'pending')
            .order_by(RawQuestion.created_at)  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return list(result.all())

    async def update_dedup_status(
        self,
        question_id: int,
        status: str,
        canonical_id: int | None = None,
    ) -> None:
        """Update the deduplication status of a raw question.

        Args:
            question_id: ID of the raw question to update
            status: New status ('unique' or 'duplicate')
            canonical_id: ID of the canonical question in fermi_questions table

        """
        statement = select(RawQuestion).where(RawQuestion.id == question_id)
        result = await self.session.exec(statement)
        question = result.one()

        question.dedup_status = status
        question.canonical_question_id = canonical_id

        self.session.add(question)
        await self.session.commit()

    async def get_yield_counts_by_seed(
        self,
        seed_ids: list[int],
    ) -> dict[int, int]:
        """Get count of unique questions per seed.

        Args:
            seed_ids: List of seed IDs to get counts for

        Returns:
            Dict mapping seed_id to count of unique questions

        """
        if not seed_ids:
            return {}

        statement = (
            select(
                RawQuestion.seed_id,
                func.count(RawQuestion.id).label('unique_count'),  # type: ignore
            )
            .where(RawQuestion.seed_id.in_(seed_ids))  # type: ignore
            .where(RawQuestion.dedup_status == 'unique')
            .group_by(RawQuestion.seed_id)  # type: ignore
        )

        result = await self.session.exec(statement)
        result_dict = dict(result.all())
        return cast(dict[int, int], result_dict)
