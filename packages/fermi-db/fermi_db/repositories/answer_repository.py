"""Repository for answer-related database operations."""

from typing import Any, cast
from uuid import UUID

from sqlalchemy import func, select, text

from fermi_db.models import AnswerEvent, AnswersQuantiles, FermiAnswer, FermiQuestion
from fermi_db.schemas import (
    PlayerPercentile,
    PlayerPercentileByCategory,
    PlayerPercentileByCategoryAndDifficulty,
    PlayerPercentileByDifficulty,
    QuestionCategory,
    QuestionDifficulty,
)

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

    async def get_ave_quantile(self, firebase_uid: str) -> PlayerPercentile:
        """Fetch a user's average answer quantiles."""
        query = text(
            """
            SELECT
                question_category,
                question_difficulty,
                AVG(score_quantile) as avg_percentile
            FROM
                answer_events
            WHERE
                user_firebase_id = :user_firebase_id
            GROUP BY
                GROUPING SETS (
                    (question_category, question_difficulty),
                    (question_category),
                    (question_difficulty),
                    ()
                )
            """,
        )
        result = await self.session.execute(
            query,
            {'user_firebase_id': firebase_uid},
        )

        by_category_and_difficulty: list[PlayerPercentileByCategoryAndDifficulty] = []
        by_category: list[PlayerPercentileByCategory] = []
        by_difficulty: list[PlayerPercentileByDifficulty] = []
        overall: int = 0

        for row in result:
            category, difficulty, avg_quantile = row
            if category and difficulty:
                by_category_and_difficulty.append(
                    PlayerPercentileByCategoryAndDifficulty(
                        category=QuestionCategory(category),
                        difficulty=QuestionDifficulty(difficulty),
                        avg_percentile=int(avg_quantile * 100),
                    ),
                )
            elif category:
                by_category.append(
                    PlayerPercentileByCategory(
                        category=QuestionCategory(category),
                        avg_percentile=int(avg_quantile * 100),
                    ),
                )
            elif difficulty:
                by_difficulty.append(
                    PlayerPercentileByDifficulty(
                        difficulty=QuestionDifficulty(difficulty),
                        avg_percentile=int(avg_quantile * 100),
                    ),
                )
            else:
                overall = int(avg_quantile * 100) if avg_quantile is not None else 0

        return PlayerPercentile(
            by_category_and_difficulty=by_category_and_difficulty,
            by_category=by_category,
            by_difficulty=by_difficulty,
            overall=overall,
        )

    async def get_latest_unanswered_questions(
        self,
        limit: int,
    ) -> list[int]:
        """Get the latest N unanswered question IDs efficiently.

        Uses a LEFT JOIN to find questions without any answer attempts.
        Only returns questions that have never been attempted (no answer record
        exists). Questions with failed attempts (success=False) are excluded
        to avoid retrying. Questions are ordered by created_at DESC (newest first).

        Args:
            limit: Maximum number of question IDs to return

        Returns:
            List of question IDs that have no answer attempts

        """
        statement = (
            select(FermiQuestion.id)  # type: ignore
            .outerjoin(FermiAnswer, FermiQuestion.id == FermiAnswer.question_id)  # type: ignore
            .where(FermiAnswer.id.is_(None))  # type: ignore
            .order_by(FermiQuestion.created_at.desc())  # type: ignore
            .limit(limit)
        )

        result = await self.session.exec(statement)
        # Extract IDs from Row objects (result.all() returns Rows, not raw integers)
        rows = result.all()
        return [row[0] for row in rows if row[0] is not None]
