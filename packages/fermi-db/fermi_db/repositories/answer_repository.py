"""Repository for answer-events-related database operations."""

from typing import Any, cast
from uuid import UUID

from sqlalchemy import func, select

from fermi_db.models import AnswerEvent, AnswersQuantiles

from . import BaseRepository


class AnswerRepository(BaseRepository):
    """Handles database operations related to answers."""

    async def add_answers(self, answers: list[AnswerEvent]) -> None:
        """Add multiple answering events to the answers table."""
        if not answers:
            return

        self.session.add_all(answers)
        await self.session.commit()

    async def get_question_quantiles(
        self,
        question_uid: UUID,
    ) -> AnswersQuantiles:
        """Compute score quantiles live from answer_events for a question."""
        score_col = cast(Any, AnswerEvent.score_number)
        question_col = cast(Any, AnswerEvent.question_uid)

        cols = [
            func.percentile_cont(0.01).within_group(score_col.asc()).label('p01'),
            func.percentile_cont(0.05).within_group(score_col.asc()).label('p05'),
            func.percentile_cont(0.10).within_group(score_col.asc()).label('p10'),
            func.percentile_cont(0.25).within_group(score_col.asc()).label('p25'),
            func.percentile_cont(0.50).within_group(score_col.asc()).label('p50'),
            func.percentile_cont(0.60).within_group(score_col.asc()).label('p60'),
            func.percentile_cont(0.75).within_group(score_col.asc()).label('p75'),
            func.percentile_cont(0.80).within_group(score_col.asc()).label('p80'),
            func.percentile_cont(0.85).within_group(score_col.asc()).label('p85'),
            func.percentile_cont(0.90).within_group(score_col.asc()).label('p90'),
            func.percentile_cont(0.95).within_group(score_col.asc()).label('p95'),
            func.percentile_cont(0.99).within_group(score_col.asc()).label('p99'),
        ]
        stmt = select(*cols).where(question_col == question_uid)

        result = await self.session.execute(stmt)
        row = result.one_or_none()
        if row is None:
            return AnswersQuantiles(question_uid=question_uid)

        m = row._mapping
        return AnswersQuantiles(
            question_uid=question_uid,
            p01=float(m['p01']) if m['p01'] is not None else 0.0,
            p05=float(m['p05']) if m['p05'] is not None else 0.0,
            p10=float(m['p10']) if m['p10'] is not None else 0.0,
            p25=float(m['p25']) if m['p25'] is not None else 0.0,
            p50=float(m['p50']) if m['p50'] is not None else 0.0,
            p60=float(m['p60']) if m['p60'] is not None else 0.0,
            p75=float(m['p75']) if m['p75'] is not None else 0.0,
            p80=float(m['p80']) if m['p80'] is not None else 0.0,
            p85=float(m['p85']) if m['p85'] is not None else 0.0,
            p90=float(m['p90']) if m['p90'] is not None else 0.0,
            p95=float(m['p95']) if m['p95'] is not None else 0.0,
            p99=float(m['p99']) if m['p99'] is not None else 0.0,
        )

    async def count_user_party_games(self, firebase_uid: str) -> int:
        """Count the number of distinct party games a user has played.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The count of distinct game_id values for this user.

        """
        stmt = select(func.count(func.distinct(AnswerEvent.game_id))).where(
            AnswerEvent.user_firebase_id == firebase_uid,  # pyright: ignore[reportArgumentType]
        )
        result = await self.session.execute(stmt)
        count = result.scalar()
        return int(count) if count is not None else 0

    async def get_overall_avg_percentile(self, firebase_uid: str) -> int:
        """Get user's overall average percentile across all party games.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The average percentile (0-100), or 0 if no games played.

        """
        stmt = select(func.avg(AnswerEvent.score_quantile)).where(  # pyright: ignore[reportArgumentType]
            AnswerEvent.user_firebase_id == firebase_uid,  # pyright: ignore[reportArgumentType]
        )
        result = await self.session.execute(stmt)
        avg_quantile = result.scalar()
        if avg_quantile is None:
            return 0
        return int(avg_quantile * 100)

    async def get_user_answer_events(
        self,
        user_id: str,
        limit: int,
    ) -> list[AnswerEvent]:
        """Get the latest N answer events for a user."""
        statement = (
            select(AnswerEvent)
            .where(AnswerEvent.user_firebase_id == user_id)  # pyright: ignore[reportArgumentType]
            .order_by(AnswerEvent.created_at.desc())
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return result.all()
