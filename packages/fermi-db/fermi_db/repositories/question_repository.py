"""Repository for question-related database operations."""

from typing import cast

from pydantic import BaseModel
from sqlmodel import select

from fermi_db.models import FermiQuestion
from fermi_db.repositories import BaseRepository


class FermiQuestionLight(BaseModel):
    """Lightweight FermiQuestion model with only id and text."""

    id: int
    text: str


class QuestionRepository(BaseRepository):
    """Handle database operations for FermiQuestion (pipeline version)."""

    async def find_similar_questions(
        self,
        embedding: list[float],
        threshold: float = 0.85,
    ) -> list[tuple[FermiQuestion, float]]:
        """Find similar questions using cosine distance.

        Args:
            embedding: The embedding vector to compare against
            threshold: Maximum cosine distance for similarity (default 0.85)

        Returns:
            List of (FermiQuestion, distance) tuples where distance <= threshold

        """
        statement = (
            select(
                FermiQuestion,
                FermiQuestion.embedding.cosine_distance(embedding).label('distance'),  # type: ignore
            )
            .where(FermiQuestion.embedding.cosine_distance(embedding) <= threshold)  # type: ignore
            .order_by('distance')
        )
        result = await self.session.exec(statement)
        return list(result.all())

    async def bulk_insert_unique_questions(
        self,
        questions: list[FermiQuestion],
    ) -> list[int]:
        """Bulk insert unique questions and return their IDs.

        Note: This method does NOT check for duplicates. Caller should
        ensure uniqueness before calling.

        Args:
            questions: List of FermiQuestion instances to insert

        Returns:
            List of inserted question IDs

        """
        if not questions:
            return []

        self.session.add_all(questions)
        await self.session.flush()  # Execute INSERT and populate IDs
        await self.session.commit()

        # IDs are now populated on the question objects via RETURNING clause
        return [q.id for q in questions]  # type: ignore

    async def get_questions_by_ids(
        self,
        question_ids: list[int],
    ) -> list[FermiQuestion]:
        """Get questions by their IDs.

        Args:
            question_ids: List of question IDs to fetch

        Returns:
            List of FermiQuestion instances that exist (regardless of answer status)

        """
        if not question_ids:
            return []

        statement = select(FermiQuestion).where(
            FermiQuestion.id.in_(question_ids),  # type: ignore
        )

        result = await self.session.exec(statement)
        return list(result.all())

    async def get_questions_light_by_ids(
        self,
        question_ids: list[int],
    ) -> list[FermiQuestionLight]:
        """Get questions (id and text only) by their IDs.

        Args:
            question_ids: List of question IDs to fetch

        Returns:
            List of FermiQuestionLight instances that exist

        """
        if not question_ids:
            return []

        statement = select(FermiQuestion.id, FermiQuestion.text).where(
            FermiQuestion.id.in_(question_ids),  # type: ignore
        )
        result = await self.session.exec(statement)

        return [
            FermiQuestionLight(id=cast(int, question_id), text=question_text)
            for question_id, question_text in result.all()
        ]
