"""Repository for answer-events-related database operations."""

from collections.abc import Mapping, Sequence
from typing import Any, cast
from uuid import UUID

from sqlalchemy import func, select

from fermi_db.models import AnswerEvent, AnswersQuantiles
from fermi_db.schemas import GameMode

from . import BaseRepository

# Minimum sample size before trusting real quantiles.
# Below this threshold, linear quantiles (0→1000) are returned to prevent
# cold-start volatility where early accurate players skew the distribution.
MIN_QUANTILE_SAMPLE_SIZE = 20
QUANTILE_PERCENTILES = (
    ('p01', 0.01),
    ('p05', 0.05),
    ('p10', 0.10),
    ('p25', 0.25),
    ('p50', 0.50),
    ('p60', 0.60),
    ('p75', 0.75),
    ('p80', 0.80),
    ('p85', 0.85),
    ('p90', 0.90),
    ('p95', 0.95),
    ('p99', 0.99),
)


def _quantile_columns(score_col: Any) -> list[Any]:
    """Return the shared sample-count and percentile SQL expressions."""
    return [
        func.count(score_col).label('cnt'),
        *[
            func.percentile_cont(percentile).within_group(score_col.asc()).label(label)
            for label, percentile in QUANTILE_PERCENTILES
        ],
    ]


def _quantiles_from_mapping(
    question_uid: UUID,
    row: Mapping[str, Any],
) -> AnswersQuantiles:
    """Map one aggregate row to quantiles with cold-start protection."""
    if int(row['cnt'] or 0) < MIN_QUANTILE_SAMPLE_SIZE:
        return AnswersQuantiles.easy(question_uid)

    values = {label: row[label] or 0.0 for label, _ in QUANTILE_PERCENTILES}
    return AnswersQuantiles(question_uid=question_uid, **values)


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

        stmt = select(*_quantile_columns(score_col)).where(
            question_col == question_uid,
        )

        result = await self.session.execute(stmt)
        row = result.one_or_none()
        if row is None:
            return AnswersQuantiles(question_uid=question_uid)

        return _quantiles_from_mapping(question_uid, row._mapping)

    async def get_questions_quantiles(
        self,
        question_uids: Sequence[UUID],
    ) -> dict[UUID, AnswersQuantiles]:
        """Compute score quantiles for many questions in a single query.

        Bulk equivalent of :meth:`get_question_quantiles`. Returns a dict mapping
        each requested ``question_uid`` to its ``AnswersQuantiles``. A uid is
        present in the result only if it has at least one answer event (the
        ``GROUP BY`` yields no row for questions with no answers); callers MUST
        default a missing uid to ``AnswersQuantiles.easy(uid)`` (cold-start linear
        quantiles), NOT all-zeros ``AnswersQuantiles(question_uid=uid)``. That
        mirrors the per-uid method's *effective* behavior: its UNGROUPED aggregate
        always returns one row with ``cnt=0`` for a no-answer question, which is
        ``< MIN_QUANTILE_SAMPLE_SIZE`` and so falls through to ``easy()`` -- its
        ``row is None`` all-zeros branch is unreachable for that ungrouped query.
        Defaulting a missing uid to all-zeros would score never-answered questions
        against a degenerate distribution. Questions whose sample count is below
        ``MIN_QUANTILE_SAMPLE_SIZE`` likewise get ``AnswersQuantiles.easy``,
        identical to the per-uid method.
        """
        if not question_uids:
            return {}

        score_col = cast(Any, AnswerEvent.score_number)
        question_col = cast(Any, AnswerEvent.question_uid)

        stmt = (
            select(question_col.label('question_uid'), *_quantile_columns(score_col))
            .where(question_col.in_(list(question_uids)))
            .group_by(question_col)
        )

        result = await self.session.execute(stmt)

        quantiles: dict[UUID, AnswersQuantiles] = {}
        for row in result.all():
            m = row._mapping
            uid = m['question_uid']
            quantiles[uid] = _quantiles_from_mapping(uid, m)
        return quantiles

    async def count_user_party_games(self, firebase_uid: str) -> int:
        """Count the number of distinct party games a user has played.

        Args:
            firebase_uid: The user's Firebase UID.

        Returns:
            The count of distinct game_id values for Party mode games.

        """
        stmt = select(func.count(func.distinct(AnswerEvent.game_id))).where(
            AnswerEvent.user_firebase_id == firebase_uid,  # pyright: ignore[reportArgumentType]
            AnswerEvent.game_mode == GameMode.PARTY,
        )
        result = await self.session.execute(stmt)
        count = result.scalar()
        return int(count) if count is not None else 0

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
