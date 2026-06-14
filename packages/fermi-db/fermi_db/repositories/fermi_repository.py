"""Repository for Fermi table operations."""

import uuid
from dataclasses import dataclass

from sqlalchemy import func
from sqlalchemy.orm import aliased
from sqlmodel import select

from fermi_db.models import Fermi, SmartSearchEvent, UserQuestionHistory
from fermi_db.repositories import BaseRepository
from fermi_db.schemas import (
    AnswerWithSnippet,
    QuestionCategory,
    QuestionDifficulty,
    QuestionStatus,
)


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
    # Gemini Flash answer fields
    gemini_flash_1_number: float | None = None
    gemini_flash_1_unit: str | None = None
    gemini_flash_2_number: float | None = None
    gemini_flash_2_unit: str | None = None
    gemini_flash_3_number: float | None = None
    gemini_flash_3_unit: str | None = None
    gemini_flash_4_number: float | None = None
    gemini_flash_4_unit: str | None = None
    gemini_flash_5_number: float | None = None
    gemini_flash_5_unit: str | None = None

    is_daily_question: bool | None = None


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

    async def get_answer_with_snippet_by_uid(
        self,
        uid: uuid.UUID,
    ) -> AnswerWithSnippet | None:
        """Get a single Answer entry by its UID.

        Args:
            uid: The unique identifier of the entry

        Returns:
            The Answer entry if found, None otherwise

        """
        statement = select(Fermi.number, Fermi.unit, Fermi.snippet).where(
            Fermi.uid == uid,
        )
        result = await self.session.exec(statement)
        tup = result.one_or_none()
        return (
            AnswerWithSnippet(number=tup[0], unit=tup[1], ai_overview=tup[2])
            if tup
            else None
        )

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

            if update.is_daily_question is not None:
                entry.is_daily_question = update.is_daily_question

            # Gemini Flash answers
            if update.gemini_flash_1_number is not None:
                entry.gemini_flash_1_number = update.gemini_flash_1_number
            if update.gemini_flash_1_unit is not None:
                entry.gemini_flash_1_unit = update.gemini_flash_1_unit
            if update.gemini_flash_2_number is not None:
                entry.gemini_flash_2_number = update.gemini_flash_2_number
            if update.gemini_flash_2_unit is not None:
                entry.gemini_flash_2_unit = update.gemini_flash_2_unit
            if update.gemini_flash_3_number is not None:
                entry.gemini_flash_3_number = update.gemini_flash_3_number
            if update.gemini_flash_3_unit is not None:
                entry.gemini_flash_3_unit = update.gemini_flash_3_unit
            if update.gemini_flash_4_number is not None:
                entry.gemini_flash_4_number = update.gemini_flash_4_number
            if update.gemini_flash_4_unit is not None:
                entry.gemini_flash_4_unit = update.gemini_flash_4_unit
            if update.gemini_flash_5_number is not None:
                entry.gemini_flash_5_number = update.gemini_flash_5_number
            if update.gemini_flash_5_unit is not None:
                entry.gemini_flash_5_unit = update.gemini_flash_5_unit

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

    async def get_unseen_similar_questions(
        self,
        query_embedding: list[float],
        count: int,
        for_user_ids: list[str],
        candidate_pool_size: int,
        similarity_floor: float,
        difficulty: QuestionDifficulty | None = None,
    ) -> list[tuple[Fermi, float]]:
        """Fetch up to N APPROVED questions semantically similar to a query.

        Two-stage selection that reuses the existing unseen-fairness ordering:

        1. **Candidates** — the ``candidate_pool_size`` nearest APPROVED, non-daily
           questions whose cosine *similarity* to ``query_embedding`` is at least
           ``similarity_floor`` (i.e. cosine distance ``<= 1 - similarity_floor``).
           The floor is a relevance gate that rejects off-topic/nonsense queries;
           the pool cap bounds how many feed the fairness stage.
        2. **Fairness** — within that floored pool, prioritize the questions seen
           by the fewest users, then fewest total times (same LEFT JOIN / ORDER BY
           as :meth:`get_unseen_random_questions`), then take ``count``.

        Callers pass ``similarity_floor`` as a cosine *similarity* in ``[0, 1]``
        (never a raw distance — that prevents inversion bugs); it is converted
        internally to ``max_distance = 1 - similarity_floor``.

        Contract: returns *up to* ``count`` rows, possibly fewer (including 0) — the
        floor can shrink the pool below ``count``. No exception is raised here; the
        caller decides what "too few" means. Each row is a ``(Fermi, distance)``
        tuple (cosine distance), so callers can derive similarity = ``1 - distance``
        for telemetry.

        Equivalent SQL::

            WITH candidates AS (
                SELECT *, (embedding <=> :query_vec) AS distance
                FROM fermi
                WHERE status = 'APPROVED'
                  AND is_daily_question = false
                  AND embedding IS NOT NULL
                  -- AND difficulty = <difficulty>
                  AND (embedding <=> :query_vec) <= :max_distance
                ORDER BY embedding <=> :query_vec
                LIMIT :candidate_pool_size
            )
            SELECT c.*, c.distance
            FROM candidates c
            LEFT JOIN (
                SELECT
                    uqh.question_uid,
                    COUNT(DISTINCT uqh.user_id) AS seen_by_user_count,
                    COUNT(uqh.id) AS total_seen_count
                FROM user_question_history AS uqh
                WHERE uqh.user_id IN (<user_ids>)
                GROUP BY uqh.question_uid
            ) AS seen_stats ON c.uid = seen_stats.question_uid
            ORDER BY
                COALESCE(seen_stats.seen_by_user_count, 0) ASC,
                COALESCE(seen_stats.total_seen_count, 0) ASC
            LIMIT :count;

        Args:
            query_embedding: The query vector to compare against (same model and
                cleaning as the corpus, so the spaces match).
            count: Maximum number of questions to return.
            for_user_ids: User IDs to check question history against.
            candidate_pool_size: Max questions to keep after the floor, before
                fairness (the ``M`` cap).
            similarity_floor: Minimum cosine similarity in ``[0, 1]``; converted to
                ``max_distance = 1 - similarity_floor``.
            difficulty: Difficulty level to filter by, or None for all.

        """
        if not for_user_ids:
            return []

        # Human units in, raw distance out: similarity floor -> max cosine distance.
        max_distance = 1 - similarity_floor

        # Stage 1: similarity-gated candidate pool. Carry the labeled cosine
        # distance through so it survives to the outer select (fairness orders on
        # seen-stats, not on distance). Same cosine_distance() pattern proven in
        # question_repository.find_similar_questions / seed_repository.
        candidates = select(
            Fermi,
            Fermi.embedding.cosine_distance(query_embedding).label('distance'),  # type: ignore
        ).where(
            Fermi.status == QuestionStatus.APPROVED,
            Fermi.is_daily_question == False,  # noqa: E712
            Fermi.embedding.is_not(None),  # type: ignore
            Fermi.embedding.cosine_distance(query_embedding) <= max_distance,  # type: ignore
        )

        if difficulty is not None:
            candidates = candidates.where(Fermi.difficulty == difficulty)

        candidates = candidates.order_by('distance').limit(candidate_pool_size)
        candidates_subquery = candidates.subquery()

        # Stage 2: fairness over the floored pool. Reuse the exact seen-stats
        # subquery from get_unseen_random_questions.
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

        # Reconstruct the Fermi entity + carried distance from the candidates CTE.
        fermi_alias = aliased(Fermi, candidates_subquery)
        statement = select(
            fermi_alias,
            candidates_subquery.c.distance,
        ).join(
            seen_stats_subquery,
            candidates_subquery.c.uid == seen_stats_subquery.c.question_uid,  # type: ignore
            isouter=True,
        )

        # Use COALESCE to treat NULLs as 0 (unseen).
        seen_by_user_count = func.coalesce(seen_stats_subquery.c.seen_by_user_count, 0)
        total_seen_count = func.coalesce(seen_stats_subquery.c.total_seen_count, 0)

        # Mirror get_unseen_random_questions' ACTUAL order_by: only the two
        # seen-stats keys. Despite that method's docstring, random_sort_key is NOT
        # applied there, so we don't apply it here either -- do not "fix" this back.
        statement = statement.order_by(
            seen_by_user_count.asc(),
            total_seen_count.asc(),
        )

        statement = statement.limit(count)

        results = await self.session.exec(statement)
        return [(fermi, distance) for fermi, distance in results.all()]

    async def insert_smart_search_event(self, event: SmartSearchEvent) -> None:
        """Persist a single smart-search telemetry event.

        Best-effort telemetry: callers should treat failures as non-fatal so a
        logging error never breaks a game start.

        Args:
            event: The SmartSearchEvent to insert.

        """
        self.session.add(event)
        await self.session.commit()
