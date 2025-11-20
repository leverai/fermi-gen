"""Repository for FermiAnswer table operations."""

from sqlalchemy.dialects.postgresql import insert
from sqlmodel import select

from fermi_db.models import FermiAnswer
from fermi_db.repositories import BaseRepository


class FermiAnswerRepository(BaseRepository):
    """Handle database operations for the FermiAnswer table."""

    async def bulk_insert_answers(
        self,
        answers: list[FermiAnswer],
    ) -> list[int]:
        """Bulk insert or update answers and return their IDs.

        Uses UPSERT (INSERT ... ON CONFLICT DO UPDATE) to handle re-answering.
        If an answer already exists for a question, it will be updated.

        Args:
            answers: List of FermiAnswer instances to insert/update

        Returns:
            List of answer IDs (inserted or updated)

        """
        if not answers:
            return []

        # Convert answers to dicts for bulk insert
        answer_dicts = [
            {
                'question_id': a.question_id,
                'number': a.number,
                'unit': a.unit,
                'snippet': a.snippet,
                'used_ai_overview': a.used_ai_overview,
                'success': a.success,
                'serp_metadata': a.serp_metadata,
                'created_at': a.created_at,
            }
            for a in answers
        ]

        # Create insert statement with ON CONFLICT DO UPDATE
        stmt = insert(FermiAnswer).values(answer_dicts)
        stmt = stmt.on_conflict_do_update(
            index_elements=['question_id'],
            set_={
                'number': stmt.excluded.number,
                'unit': stmt.excluded.unit,
                'snippet': stmt.excluded.snippet,
                'used_ai_overview': stmt.excluded.used_ai_overview,
                'success': stmt.excluded.success,
                'serp_metadata': stmt.excluded.serp_metadata,
                'created_at': stmt.excluded.created_at,
            },
        )

        # Execute the upsert
        await self.session.execute(stmt)
        await self.session.commit()

        # Fetch the IDs for the question_ids we just inserted/updated
        question_ids = [a.question_id for a in answers]
        result = await self.session.exec(
            select(FermiAnswer.id).where(
                FermiAnswer.question_id.in_(question_ids),  # type: ignore
            ),
        )
        # IDs are always populated after insert, so we can safely cast
        return [id for id in result.all() if id is not None]
