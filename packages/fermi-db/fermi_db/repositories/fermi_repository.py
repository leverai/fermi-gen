"""Repository for Fermi table operations."""

import uuid
from dataclasses import dataclass

from sqlalchemy import func
from sqlmodel import select

from fermi_db.models import Fermi, UserQuestionHistory
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import QuestionCategory, QuestionDifficulty, QuestionStatus


@dataclass
class FermiUpdate:
    """Represents an update to a Fermi entry."""

    uid: uuid.UUID
    text: str | None = None
    number: float | None = None
    unit: str | None = None
    snippet: str | None = None
    difficulty: QuestionDifficulty | None = None
    category: QuestionCategory | None = None
    status: QuestionStatus | None = None
    # LLM answer fields
    gpt_5_1_number: float | None = None
    gpt_5_1_unit: str | None = None
    gpt_5_mini_number: float | None = None
    gpt_5_mini_unit: str | None = None
    gpt_5_nano_number: float | None = None
    gpt_5_nano_unit: str | None = None


class FermiRepository(BaseRepository):
    """Handle database operations for the Fermi table."""

    async def get_pending_review(self, limit: int = 100) -> list[Fermi]:
        """Get entries with PENDING_REVIEW status.

        Args:
            limit: Maximum number of entries to return

        Returns:
            List of Fermi entries awaiting review

        """
        statement = (
            select(Fermi)
            .where(Fermi.status == QuestionStatus.PENDING_REVIEW)
            .order_by(Fermi.created_at.desc())  # type: ignore
            .limit(limit)
        )
        result = await self.session.exec(statement)
        return list(result.all())

    async def get_by_uid(self, uid: uuid.UUID) -> Fermi | None:
        """Get a single Fermi entry by its UID.

        Args:
            uid: The unique identifier of the entry

        Returns:
            The Fermi entry if found, None otherwise

        """
        statement = select(Fermi).where(Fermi.uid == uid)
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def bulk_update(self, updates: list[FermiUpdate]) -> int:
        """Bulk update Fermi entries.

        Args:
            updates: List of FermiUpdate objects containing the changes

        Returns:
            Number of entries updated

        """
        if not updates:
            return 0

        updated_count = 0
        for update in updates:
            entry = await self.get_by_uid(update.uid)
            if entry is None:
                continue

            # Apply non-None updates
            if update.text is not None:
                entry.text = update.text
            if update.number is not None:
                entry.number = update.number
            if update.unit is not None:
                entry.unit = update.unit
            if update.snippet is not None:
                entry.snippet = update.snippet
            if update.difficulty is not None:
                entry.difficulty = update.difficulty
            if update.category is not None:
                entry.category = update.category
            if update.status is not None:
                entry.status = update.status
            if update.gpt_5_1_number is not None:
                entry.gpt_5_1_number = update.gpt_5_1_number
            if update.gpt_5_1_unit is not None:
                entry.gpt_5_1_unit = update.gpt_5_1_unit
            if update.gpt_5_mini_number is not None:
                entry.gpt_5_mini_number = update.gpt_5_mini_number
            if update.gpt_5_mini_unit is not None:
                entry.gpt_5_mini_unit = update.gpt_5_mini_unit
            if update.gpt_5_nano_number is not None:
                entry.gpt_5_nano_number = update.gpt_5_nano_number
            if update.gpt_5_nano_unit is not None:
                entry.gpt_5_nano_unit = update.gpt_5_nano_unit

            self.session.add(entry)
            updated_count += 1

        await self.session.commit()
        return updated_count

    async def get_unseen_random_questions(
        self,
        count: int,
        for_user_ids: list[str],
        categories: list[QuestionCategory] | None = None,
        difficulty: QuestionDifficulty | None = None,
    ) -> list[Fermi]:
        """Fetch up to N APPROVED questions, prioritizing less-seen ones.

        Only returns questions with status = APPROVED (human-reviewed).
        Questions are prioritized by those seen by the fewest users, then by
        the fewest total times among those users.

        Equivalent SQL::

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
            WHERE fq.status = 'APPROVED'
            -- AND fq.category IN (<categories>)
            -- AND fq.difficulty = <difficulty>
            ORDER BY
                COALESCE(seen_stats.seen_by_user_count, 0) ASC,
                COALESCE(seen_stats.total_seen_count, 0) ASC,
                fq.random_sort_key ASC
            LIMIT <count>;

        Args:
            count: Maximum number of questions to return.
            for_user_ids: User IDs to check question history against.
            categories: List of categories to filter by, or None for all.
            difficulty: Difficulty level to filter by, or None for all.

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

        # Main query - only return APPROVED questions (human-reviewed)
        # Also exclude questions reserved for Daily Question mode
        statement = select(Fermi).where(
            Fermi.status == QuestionStatus.APPROVED,
            Fermi.is_daily_question == False,  # noqa: E712
        )

        if categories:
            statement = statement.where(Fermi.category.in_(categories))  # type: ignore
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
