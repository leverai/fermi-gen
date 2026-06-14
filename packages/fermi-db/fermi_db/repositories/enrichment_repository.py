"""Repository for enrichment-related database operations."""

from typing import cast
from uuid import UUID

from sqlalchemy import text
from sqlmodel import select

from fermi_db.models import Fermi, FermiAnswer, FermiQuestion
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import QuestionCategory, QuestionDifficulty, QuestionStatus


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

    async def sync_fermi_table(self) -> int:
        """Sync the fermi table with new questions from source tables.

        Finds questions that:
        - Have successful answers (fermi_answers.success = true)
        - Have all three GPT LLM answers (gpt-5.1, gpt-5-mini, gpt-5-nano)
        - Have all five Gemini Flash LLM answers (gemini-flash-1 through 5)
        - Are not yet in the fermi table

        Inserts them with status = PENDING_REVIEW.

        Returns:
            Number of new questions inserted

        """
        # Use raw SQL for the complex insert with multiple joins
        # This mirrors the logic from the original materialized view
        result = await self.session.exec(  # type: ignore
            text("""
            INSERT INTO fermi (
                uid,
                question_id,
                text,
                question_source,
                answer_id,
                number,
                unit,
                snippet,
                used_ai_overview,
                difficulty,
                category,
                embedding,
                random_sort_key,
                created_at,
                updated_at,
                gpt_5_1_number,
                gpt_5_1_unit,
                gpt_5_mini_number,
                gpt_5_mini_unit,
                gpt_5_nano_number,
                gpt_5_nano_unit,
                gemini_flash_1_number,
                gemini_flash_1_unit,
                gemini_flash_2_number,
                gemini_flash_2_unit,
                gemini_flash_3_number,
                gemini_flash_3_unit,
                gemini_flash_4_number,
                gemini_flash_4_unit,
                gemini_flash_5_number,
                gemini_flash_5_unit,
                status
            )
            SELECT
                uuid_generate_v5(
                    '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid,
                    fq.id::text
                ) AS uid,
                fq.id AS question_id,
                fq.text,
                fq.source AS question_source,
                fa.id AS answer_id,
                fa.number,
                fa.unit,
                fa.snippet,
                fa.used_ai_overview,
                fq.difficulty,
                fq.category,
                fq.embedding,
                floor(random() * 2147483647)::int AS random_sort_key,
                fq.created_at,
                GREATEST(
                    fa.created_at,
                    la_51.created_at,
                    la_mini.created_at,
                    la_nano.created_at,
                    la_gf1.created_at,
                    la_gf2.created_at,
                    la_gf3.created_at,
                    la_gf4.created_at,
                    la_gf5.created_at
                ) AS updated_at,
                la_51.number AS gpt_5_1_number,
                la_51.unit AS gpt_5_1_unit,
                la_mini.number AS gpt_5_mini_number,
                la_mini.unit AS gpt_5_mini_unit,
                la_nano.number AS gpt_5_nano_number,
                la_nano.unit AS gpt_5_nano_unit,
                la_gf1.number AS gemini_flash_1_number,
                la_gf1.unit AS gemini_flash_1_unit,
                la_gf2.number AS gemini_flash_2_number,
                la_gf2.unit AS gemini_flash_2_unit,
                la_gf3.number AS gemini_flash_3_number,
                la_gf3.unit AS gemini_flash_3_unit,
                la_gf4.number AS gemini_flash_4_number,
                la_gf4.unit AS gemini_flash_4_unit,
                la_gf5.number AS gemini_flash_5_number,
                la_gf5.unit AS gemini_flash_5_unit,
                'PENDING_REVIEW' AS status
            FROM fermi_answers fa
            INNER JOIN fermi_questions fq ON fa.question_id = fq.id
            INNER JOIN llm_answers la_51 ON fq.id = la_51.question_id
                AND la_51.model = 'gpt-5.1'
            INNER JOIN llm_answers la_mini ON fq.id = la_mini.question_id
                AND la_mini.model = 'gpt-5-mini'
            INNER JOIN llm_answers la_nano ON fq.id = la_nano.question_id
                AND la_nano.model = 'gpt-5-nano'
            INNER JOIN llm_answers la_gf1 ON fq.id = la_gf1.question_id
                AND la_gf1.model = 'gemini-flash-1'
            INNER JOIN llm_answers la_gf2 ON fq.id = la_gf2.question_id
                AND la_gf2.model = 'gemini-flash-2'
            INNER JOIN llm_answers la_gf3 ON fq.id = la_gf3.question_id
                AND la_gf3.model = 'gemini-flash-3'
            INNER JOIN llm_answers la_gf4 ON fq.id = la_gf4.question_id
                AND la_gf4.model = 'gemini-flash-4'
            INNER JOIN llm_answers la_gf5 ON fq.id = la_gf5.question_id
                AND la_gf5.model = 'gemini-flash-5'
            WHERE fa.success = true
            AND NOT EXISTS (
                SELECT 1 FROM fermi f WHERE f.question_id = fq.id
            )
            """),  # type: ignore
        )
        await self.session.commit()
        return result.rowcount if result.rowcount else 0  # type: ignore

    async def update_question_status(
        self,
        question_uid: UUID,
        status: QuestionStatus,
    ) -> bool:
        """Update a question's review status.

        Args:
            question_uid: The question's unique identifier
            status: New status (PENDING_REVIEW, APPROVED, or REJECTED)

        Returns:
            True if the question was found and updated, False otherwise

        """
        statement = select(Fermi).where(Fermi.uid == question_uid)
        result = await self.session.exec(statement)
        fermi = result.one_or_none()

        if fermi is None:
            return False

        fermi.status = status
        self.session.add(fermi)
        await self.session.commit()
        return True

    async def bulk_update_question_status(
        self,
        status: QuestionStatus,
        *,
        from_status: QuestionStatus | None = None,
    ) -> int:
        """Bulk update status for all questions (optionally filtered by current status).

        Args:
            status: New status to set
            from_status: If provided, only update questions with this current status

        Returns:
            Number of questions updated

        """
        if from_status is not None:
            result = await self.session.exec(  # type: ignore
                text("""
                UPDATE fermi SET status = :new_status WHERE status = :from_status
                """).bindparams(new_status=status.value, from_status=from_status.value),
            )
        else:
            result = await self.session.exec(  # type: ignore
                text("""
                UPDATE fermi SET status = :new_status
                """).bindparams(new_status=status.value),
            )
        await self.session.commit()
        return result.rowcount if result.rowcount else 0  # type: ignore
