"""Repository for LLMAnswer table operations."""

from typing import cast

from sqlalchemy.dialects.postgresql import insert
from sqlmodel import select

from fermi_db.models import FermiAnswer, FermiQuestion, LLMAnswer
from fermi_db.repositories import BaseRepository


class LLMAnswerRepository(BaseRepository):
    """Handle database operations for the LLMAnswer table."""

    async def get_questions_needing_llm_answer(
        self,
        model: str,
        limit: int,
    ) -> list[tuple[int, str, str | None]]:
        """Get questions with successful SerpAPI answers but no LLM answer.

        Finds questions that have been answered by SerpAPI but not yet by the
        specified LLM model.

        Args:
            model: The LLM model name (e.g., 'gpt-5.1', 'gpt-5-mini', 'gpt-5-nano')
            limit: Maximum number of questions to return

        Returns:
            List of (question_id, question_text, answer_unit) tuples

        """
        # Subquery to get question_ids already answered by this model
        answered_subq = (
            select(LLMAnswer.question_id).where(LLMAnswer.model == model).subquery()
        )

        # Get questions with successful SerpAPI answers not yet answered by this model
        statement = (
            select(FermiQuestion.id, FermiQuestion.text, FermiAnswer.unit)
            .select_from(FermiQuestion)
            .join(FermiAnswer, FermiQuestion.id == FermiAnswer.question_id)  # type: ignore
            .where(FermiAnswer.success.is_(True))  # type: ignore
            .where(FermiQuestion.id.notin_(select(answered_subq.c.question_id)))  # type: ignore
            .order_by(FermiQuestion.created_at)  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return cast(list[tuple[int, str, str | None]], list(result.all()))

    async def bulk_insert_llm_answers(
        self,
        answers: list[LLMAnswer],
    ) -> list[int]:
        """Bulk insert or update LLM answers and return their IDs.

        Uses UPSERT (INSERT ... ON CONFLICT DO UPDATE) to handle re-answering.
        If an answer already exists for a question+model, it will be updated.

        Args:
            answers: List of LLMAnswer instances to insert/update

        Returns:
            List of answer IDs (inserted or updated)

        """
        if not answers:
            return []

        # Convert answers to dicts for bulk insert
        answer_dicts = [
            {
                'question_id': a.question_id,
                'model': a.model,
                'number': a.number,
                'unit': a.unit,
                'created_at': a.created_at,
            }
            for a in answers
        ]

        # Create insert statement with ON CONFLICT DO UPDATE
        stmt = insert(LLMAnswer).values(answer_dicts)
        stmt = stmt.on_conflict_do_update(
            constraint='uq_llm_answers_question_model',
            set_={
                'number': stmt.excluded.number,
                'unit': stmt.excluded.unit,
                'created_at': stmt.excluded.created_at,
            },
        )

        # Execute the upsert
        await self.session.execute(stmt)
        await self.session.commit()

        # Fetch the IDs for the question_ids and models we just inserted/updated
        question_ids = [a.question_id for a in answers]
        models = [a.model for a in answers]
        result = await self.session.exec(
            select(LLMAnswer.id).where(
                LLMAnswer.question_id.in_(question_ids),  # type: ignore
                LLMAnswer.model.in_(models),  # type: ignore
            ),
        )
        return [id for id in result.all() if id is not None]
