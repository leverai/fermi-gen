"""Repository for enrichment-related database operations."""

from typing import cast

from sqlalchemy import text
from sqlmodel import select

from fermi_db.models import FermiAnswer, FermiQuestion
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import QuestionCategory, QuestionDifficulty


class EnrichmentRepository(BaseRepository):
    """Handle database operations for enrichment (category, difficulty)."""

    async def get_questions_needing_category(
        self,
        limit: int,
    ) -> list[tuple[int, str]]:
        """Get successfully answered questions without a category.

        Returns:
            List of (question_id, text) tuples for questions that need categorization

        """
        statement = (
            select(FermiQuestion.id, FermiQuestion.text)
            .select_from(FermiQuestion)
            .join(FermiAnswer, FermiQuestion.id == FermiAnswer.question_id)  # type: ignore
            .where(FermiQuestion.category.is_(None))  # type: ignore
            .where(FermiAnswer.success.is_(True))  # type: ignore
            .order_by(FermiQuestion.created_at)  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return cast(list[tuple[int, str]], list(result.all()))

    async def get_questions_needing_difficulty(
        self,
        limit: int,
    ) -> list[tuple[int, str]]:
        """Get successfully answered questions without a difficulty.

        Returns:
            List of (question_id, text) tuples needing difficulty assessment

        """
        statement = (
            select(FermiQuestion.id, FermiQuestion.text)
            .select_from(FermiQuestion)
            .join(
                FermiAnswer,
                FermiQuestion.id == FermiAnswer.question_id,  # type: ignore
            )
            .where(FermiQuestion.difficulty.is_(None))  # type: ignore
            .where(FermiAnswer.success.is_(True))  # type: ignore
            .order_by(FermiQuestion.created_at)  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return cast(list[tuple[int, str]], list(result.all()))

    async def batch_update_categories(
        self,
        updates: list[tuple[int, QuestionCategory]],
    ) -> None:
        """Batch update categories for multiple questions.

        Args:
            updates: List of (question_id, category) tuples

        """
        if not updates:
            return

        # Use SQLAlchemy Core for efficient bulk update
        for question_id, category in updates:
            question = await self.session.get_one(FermiQuestion, question_id)
            question.category = category
            self.session.add(question)

        await self.session.commit()

    async def batch_update_difficulties(
        self,
        updates: list[tuple[int, QuestionDifficulty]],
    ) -> None:
        """Batch update difficulties for multiple questions.

        Args:
            updates: List of (question_id, difficulty) tuples

        """
        if not updates:
            return

        # Use SQLAlchemy Core for efficient bulk update
        for question_id, difficulty in updates:
            question = await self.session.get_one(FermiQuestion, question_id)
            question.difficulty = difficulty
            self.session.add(question)

        await self.session.commit()

    async def refresh_materialized_view(self) -> None:
        """Refresh the fermi materialized view."""
        await self.session.exec(  # type: ignore
            text('REFRESH MATERIALIZED VIEW fermi'),  # type: ignore
        )
        await self.session.commit()
