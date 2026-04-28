"""Repository for answer-events-related database operations."""

from typing import Any, cast
from uuid import UUID

from sqlalchemy import func, select

from fermi_db.models import AnswerEvent, AnswersQuantiles

from . import BaseRepository

# Minimum sample size before trusting real quantiles.
# Below this threshold, linear quantiles (0→1000) are returned to prevent
# cold-start volatility where early accurate players skew the distribution.
MIN_QUANTILE_SAMPLE_SIZE = 20


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
        """Compute score quantiles live from answer_events for a question.

        Returns linear quantiles (0→1000) when sample count is below
        MIN_QUANTILE_SAMPLE_SIZE to prevent cold-start volatility.
        """
        score_col = cast(Any, AnswerEvent.score_number)
        question_col = cast(Any, AnswerEvent.question_uid)

        cols = [
            func.count(score_col).label('cnt'),
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
        sample_count = m['cnt'] or 0
        sample_count = int(sample_count)

        # Return linear quantiles for cold-start protection
        if sample_count < MIN_QUANTILE_SAMPLE_SIZE:
            return AnswersQuantiles.easy(question_uid)

        return AnswersQuantiles(
            question_uid=question_uid,
            p01=m['p01'] or 0.0,
            p05=m['p05'] or 0.0,
            p10=m['p10'] or 0.0,
            p25=m['p25'] or 0.0,
            p50=m['p50'] or 0.0,
            p60=m['p60'] or 0.0,
            p75=m['p75'] or 0.0,
            p80=m['p80'] or 0.0,
            p85=m['p85'] or 0.0,
            p90=m['p90'] or 0.0,
            p95=m['p95'] or 0.0,
            p99=m['p99'] or 0.0,
        )

    async def get_overall_avg_percentile(self, firebase_uid: str) -> int:
        """Get user's overall percentile across all party games.

        Computes the player's global percentile by comparing their average score
        against all other players' average scores using percent_rank().

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The percentile (0-100), or 0 if no games played.

        """
        # Subquery: compute average score per player
        player_avgs = (
            select(
                AnswerEvent.user_firebase_id,
                func.avg(AnswerEvent.score_number).label('avg_score'),
            )
            .group_by(AnswerEvent.user_firebase_id)
            .subquery()
        )

        # Use percent_rank() window function to compute percentile in one query
        ranked = (
            select(
                player_avgs.c.user_firebase_id,
                (
                    func.percent_rank().over(order_by=player_avgs.c.avg_score) * 100
                ).label('percentile'),
            )
            .select_from(player_avgs)
            .subquery()
        )

        stmt = select(ranked.c.percentile).where(
            ranked.c.user_firebase_id == firebase_uid,  # pyright: ignore[reportArgumentType]
        )
        result = await self.session.execute(stmt)
        percentile = result.scalar()
        return int(percentile) if percentile is not None else 100

    async def get_overall_avg_percentiles_batch(
        self,
        firebase_uids: list[str],
    ) -> dict[str, int]:
        """Get overall percentiles for multiple users in a single query.

        Args:
            firebase_uids: List of Firebase UIDs.

        Returns:
            Dict mapping firebase_uid to percentile (0-100), defaulting to 100.

        """
        if not firebase_uids:
            return {}

        # Subquery: compute average score per player
        player_avgs = (
            select(
                AnswerEvent.user_firebase_id,
                func.avg(AnswerEvent.score_number).label('avg_score'),
            )
            .group_by(AnswerEvent.user_firebase_id)
            .subquery()
        )

        # Use percent_rank() window function to compute percentile
        ranked = (
            select(
                player_avgs.c.user_firebase_id,
                (
                    func.percent_rank().over(order_by=player_avgs.c.avg_score) * 100
                ).label('percentile'),
            )
            .select_from(player_avgs)
            .subquery()
        )

        stmt = select(
            ranked.c.user_firebase_id,
            ranked.c.percentile,
        ).where(
            ranked.c.user_firebase_id.in_(firebase_uids),  # pyright: ignore[reportArgumentType]
        )
        result = await self.session.execute(stmt)
        rows = result.all()
        return {row[0]: int(row[1]) if row[1] is not None else 100 for row in rows}

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
