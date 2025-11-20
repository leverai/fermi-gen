"""Repository for user history-related database operations."""

from collections.abc import Iterable
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert
from sqlmodel import select

from fermi_db.models import Fermi, UserQuestionHistory
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import QuestionCategory, QuestionDifficulty


class UserHistoryRepository(BaseRepository):
    """Handles database operations related to user history."""

    async def get_unseen_random_questions(
        self,
        count: int,
        for_user_ids: list[str],
        category: QuestionCategory | None = None,
        difficulty: QuestionDifficulty | None = None,
    ) -> list[Fermi]:
        """Fetch up to N questions, prioritizing those seen by the fewest users,
        then by the fewest total times among those users, with random ordering within
        each group.

        Equivalent SQL:
        SELECT fq.*
        FROM fermi AS fq
        LEFT JOIN (
            SELECT
                uqh.question_uid,
                COUNT(DISTINCT uqh.user_id) AS seen_by_user_count,
                COUNT(uqh.id) AS total_seen_count
            FROM user_question_history AS uqh
            WHERE uqh.user_id IN (<user_ids>)
            GROUP BY uqh.question_uid
        ) AS seen_stats ON fq.uid = seen_stats.question_uid
        -- Note: No status filter - materialized view has only answered questions
        -- AND fq.category = <category>
        -- AND fq.difficulty = <difficulty>
        ORDER BY
            COALESCE(seen_stats.seen_by_user_count, 0) ASC,
            COALESCE(seen_stats.total_seen_count, 0) ASC,
            fq.random_sort_key ASC
        LIMIT <count>;
        """
        if not for_user_ids:
            return []

        # Subquery: for each question, count how many users saw it and how many total
        # times
        seen_stats_subquery = (
            select(
                UserQuestionHistory.question_uid,
                func.count(func.distinct(UserQuestionHistory.user_id)).label(
                    'seen_by_user_count',
                ),
                func.count(UserQuestionHistory.id).label('total_seen_count'),  # type: ignore
            )
            .where(UserQuestionHistory.user_id.in_(for_user_ids))  # type: ignore
            .group_by(UserQuestionHistory.question_uid)  # type: ignore
            .subquery()
        )

        # Main query
        # Note: No status filter - materialized view has only answered questions
        statement = select(Fermi)

        if category is not None:
            statement = statement.where(Fermi.category == category)
        if difficulty is not None:
            statement = statement.where(Fermi.difficulty == difficulty)

        # Join the seen statistics
        statement = statement.join(
            seen_stats_subquery,
            Fermi.uid == seen_stats_subquery.c.question_uid,  # type: ignore
            isouter=True,
        )

        # Use COALESCE to treat NULLs as 0 (unseen)
        seen_by_user_count = func.coalesce(seen_stats_subquery.c.seen_by_user_count, 0)
        total_seen_count = func.coalesce(seen_stats_subquery.c.total_seen_count, 0)

        # Sort by: (1) fewest users, (2) fewest total times
        statement = statement.order_by(
            seen_by_user_count.asc(),
            total_seen_count.asc(),
        )

        # Limit the results
        statement = statement.limit(count)

        results = await self.session.exec(statement)
        return list(results.all())

    async def add_questions_to_users_history(
        self,
        user_ids: Iterable[str],
        question_uids: Iterable[UUID],
    ) -> None:
        """Add multiple questions to multiple users' seen history."""
        if not user_ids or not question_uids:
            return

        insert_stmt = insert(UserQuestionHistory).values(
            [
                {
                    'user_id': uid,
                    'question_uid': qid,
                    'seen_at': func.now(),
                }
                for uid in user_ids
                for qid in question_uids
            ],
        )

        await self.session.execute(insert_stmt)  # type: ignore
        await self.session.commit()
